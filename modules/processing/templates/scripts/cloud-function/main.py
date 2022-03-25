from base64 import b64decode
from json import loads
from google.cloud import compute_v1
import os 
import random
import string
from sys import exit

def get_random_string(length):
    letters = string.ascii_lowercase
    result_str = ''.join(random.choice(letters) for i in range(length))
    return result_str


def create_instance_from_template(
    project_id: str, 
    zone: str, 
    instance_name,
    instance_template_url: str,
    bucket_name: str,
    object_name: str,
    ) -> compute_v1.Instance:
    """
    Creates a Compute Engine VM instance from an instance template.

    Args:
        project_id: ID or number of the project you want to use.
        zone: Name of the zone you want to check, for example: us-west3-b
        instance_name: Name of the new instance.
        instance_template_url: URL of the instance template used for creating the new instance.

    Returns:
        Instance object.
    """
    operation_client = compute_v1.ZoneOperationsClient()
    instance_client = compute_v1.InstancesClient()

    instance_insert_request = compute_v1.InsertInstanceRequest()
    instance_insert_request.project = project_id
    instance_insert_request.zone = zone
    instance_insert_request.source_instance_template = instance_template_url
    instance_insert_request.instance_resource.name = instance_name    
    instance_insert_request.instance_resource.metadata.items = [
        {
            "key": "startup-script",
            "value": os.environ.get("STARTUP_SCRIPT")
        },
        {
            'key': 'object',
            'value': object_name 
        }, 
        {
            'key': 'bucket',
            'value': bucket_name
        }]

    op = instance_client.insert_unary(instance_insert_request)
    
    operation_client.wait(project=project_id, zone=zone, operation=op.name)
    
    return instance_client.get(project=project_id, zone=zone, instance=instance_name)


def run(event, context):
    """Triggered from a message on a Cloud Pub/Sub topic.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    data = loads(b64decode(event["data"]).decode("utf-8"))
    
    # check if file has the content type zip instead of the Velociraptor executables
    if data["contentType"] != "application/zip":
        return exit()

    project_id =  os.environ.get("PROJECT_ID")
    zone =  os.environ.get("ZONE")
    instance_template_url =  os.environ.get("TEMPLATE_URL", "Variable TEMPLATE_URL not set")
    instance_name = f"rotterdam-plaso-{get_random_string(4)}"
    bucket_name = data["bucket"]
    object_name = data["name"]
   
    create_instance_from_template(
        project_id,
        zone,
        instance_name,
        instance_template_url,
        bucket_name,
        object_name
    )