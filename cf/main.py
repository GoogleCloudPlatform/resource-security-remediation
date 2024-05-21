import base64
import binascii
import json
import logging
import re
import sys
import datetime

from googleapiclient import discovery
from google.cloud import appengine_admin_v1
from google.cloud import securitycenter
from google.cloud.securitycenter_v1 import Finding
from google.protobuf import field_mask_pb2


class Error(Exception):
  pass

def _parse_event(event):
  'Check PubSub event and return asset feed data.'
  if not event or 'data' not in event:
    raise Error('no event received, or no data in event')
  logging.info('parsing event data')
  try:
    data = base64.b64decode(event['data'])
    return json.loads(data)
  except binascii.Error as e:
    logging.info('received event: %s' % event)
    raise Error('cannot decode event data: %s' % e)
  except json.JSONDecodeError as e:
    logging.info('received data: %s', data)
    raise Error('event data not in JSON format: %s' % e)


def _enable_ingress_only_networking(appengine):
    service = discovery.build('appengine', 'v1')
    if 'name' in appengine['asset']['resource']['data']:
      if appengine['asset']['assetType'] == "appengine.googleapis.com/Service":
          app_id = appengine['asset']['resource']['data']['name']
          project_id = app_id.split("/")[1]
          app_id = f"apps/{project_id}"
      else:
          app_id = appengine['asset']['resource']['data']['name']
    else:
      app_id = f"apps/{appengine['asset']['resource']['data']['id']}"
    client = appengine_admin_v1.ServicesClient()
    request = appengine_admin_v1.ListServicesRequest(parent=app_id)
    services = client.list_services(request)

    for service in services:
        name = service.name
        # Fetch the existing service configuration 
        appservice = client.get_service(request={"name": name})
        
        # Check if the service already has internal only ingress
        if appservice.network_settings.ingress_traffic_allowed != appengine_admin_v1.NetworkSettings.IngressTrafficAllowed.INGRESS_TRAFFIC_ALLOWED_INTERNAL_ONLY:

            appservice.network_settings.ingress_traffic_allowed = appengine_admin_v1.NetworkSettings.IngressTrafficAllowed.INGRESS_TRAFFIC_ALLOWED_INTERNAL_ONLY

            try:
                update_mask = {"paths": ["network_settings"]}   # Specify field mask
                updated_service = client.update_service(request={"name": name, "service": appservice, "update_mask": update_mask})
                updated_service.result()
                logging.info(f"Updated service '{name}' to internal-only ingress.")
            except Exception as e:
                logging.info(f"Error updating service '{name}': {e}")
        else:
            logging.info(f"Service '{name}' already has internal-only ingress.")

def _create_custom_finding(appengine):
    # Create a new client.
    client = securitycenter.SecurityCenterClient()

    # Use the current time as the finding "event time".
    event_time = datetime.datetime.now(tz=datetime.timezone.utc)
    parent = next(item for item in appengine['asset']['ancestors'] if item.startswith('organizations/'))
    for i, source in enumerate(client.list_sources(request={"parent": parent})):
       if source.display_name == "app_engine_iap_finding_source":
          source_name = source.name
    app_id = appengine['asset']['resource']['data']['id']
    finding_id = re.sub(r'[^\w\s]', '', app_id)
    resource_name = appengine['asset']['name']

    finding = Finding(
        state=Finding.State.ACTIVE,
        resource_name=resource_name,
        category="APP_ENGINE_IAP_DISABLED",
        event_time=event_time,
        severity=Finding.Severity.HIGH,
        finding_class="VULNERABILITY"
    )
    try:
        created_finding = client.create_finding(
            request={"parent": source_name, "finding_id": finding_id, "finding": finding}
        )
        logging.info(created_finding)
    except Exception as e:
        logging.error(f"Error creating finding. Finding {finding_id} already exists. Activating finding state if inactive")
        _update_custom_finding_active(appengine)

def _update_custom_finding_inactive(appengine):
    client = securitycenter.SecurityCenterClient()
    parent = next(item for item in appengine['asset']['ancestors'] if item.startswith('organizations/'))
    for i, source in enumerate(client.list_sources(request={"parent": parent})):
       if source.display_name == "app_engine_iap_finding_source":
          source_name = source.name
    app_id = appengine['asset']['resource']['data']['id']
    finding_id = re.sub(r'[^\w\s]', '', app_id)
    finding_name = f"{source_name}/findings/{finding_id}"
    # Call the API to change the finding state to inactive as of now.
    new_finding = client.set_finding_state(
    request={
        "name": finding_name,
        "state": Finding.State.INACTIVE,
        "start_time": datetime.datetime.now(tz=datetime.timezone.utc),
      }
    ) 
    logging.info(f"IAP is enabled and the SCC finding {new_finding.name} is now inactive")

def _update_custom_finding_active(appengine):
    client = securitycenter.SecurityCenterClient()
    event_time = datetime.datetime.now(tz=datetime.timezone.utc)
    field_mask = field_mask_pb2.FieldMask(
        paths=["event_time","state","severity","finding_class"]
    )
    parent = next(item for item in appengine['asset']['ancestors'] if item.startswith('organizations/'))
    for i, source in enumerate(client.list_sources(request={"parent": parent})):
       if source.display_name == "app_engine_iap_finding_source":
          source_name = source.name
    app_id = appengine['asset']['resource']['data']['id']
    finding_id = re.sub(r'[^\w\s]', '', app_id)
    finding_name = f"{source_name}/findings/{finding_id}"
    # Call the API to change the finding state to inactive as of now.
    finding = Finding(
        name= finding_name,
        state=Finding.State.ACTIVE,
        category="APP_ENGINE_IAP_DISABLED",
        event_time=event_time,
        severity=Finding.Severity.HIGH,
        finding_class="VULNERABILITY"
    )

    new_finding = client.update_finding(
        request={"finding": finding, "update_mask": field_mask}
    )

    logging.info(f"IAP is disabled and the SCC finding {new_finding.name} is now active")

def main(event=None, context=None):
  'Cloud Function entry point.'
  logging.basicConfig(level=logging.INFO)
  try:
    data = _parse_event(event)
  except Error as e:
    logging.critical(e.args[0])
    return
  # logging.info(appengine)
  logging.info(data)
  if data['asset']['assetType'] == "appengine.googleapis.com/Service":
     _enable_ingress_only_networking(data)
  else:
    # Check if IaP is enabled in App Engine
    if 'iap' in data['asset']['resource']['data']:
      if 'enabled' in data['asset']['resource']['data']['iap']:
        if data['asset']['resource']['data']['iap']['enabled'] is True:
          logging.info('IaP is enabled in App Engine application.')
          _update_custom_finding_inactive(data)
        else:
          logging.info('IaP is not enabled in App Engine application.')
          _enable_ingress_only_networking(data)
          _create_custom_finding(data)
      else:
        logging.info('IaP is not enabled in App Engine application.')
        _enable_ingress_only_networking(data)
        _create_custom_finding(data)
    else:
      logging.info('IaP is not enabled in App Engine application.')
      _enable_ingress_only_networking(data)
      _create_custom_finding(data)
