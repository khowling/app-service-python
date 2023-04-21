import os, uuid
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, BlobClient, ContainerClient
from flask import Flask


default_credential = DefaultAzureCredential(exclude_shared_token_cache_credential=True)

blob_service_client = BlobServiceClient(account_url=os.environ.get('BLOB_ACCOUNT_URL'), credential=default_credential)
container_client = blob_service_client.get_container_client(container= os.environ.get('BLOB_CONTAINER_NAME'))


app = Flask(__name__)


@app.route('/')
def hello():
    blobstr = 'Blobs : '
    blob_list = container_client.list_blobs()
    for blob in blob_list:
       blobstr = blobstr + ', ' + blob.name

    return 'Hello, World, blob list: %s' %blobstr 

