try:
    import boto3                  
except ImportError:
    import boto as boto3
from datetime import datetime
import json
import logging

def manifest_for_bucket(bucket_name): 
    # session = boto3.Session(profile_name='publicdata')
    today_timestamp = datetime.now().strftime('%Y-%m-%d')
    prefix = '%s/%s/%s' % (bucket_name,bucket_name,today_timestamp)
    s3 = boto3.resource('s3')
    bucket = s3.Bucket(bucket_name)
    manifest_obj = [k for k in bucket.objects.filter(Prefix=prefix) if k.key[-4:] == 'json'][0]
    logging.info("Got: %s" % manifest_obj)

    manifest = json.loads(manifest_obj.get()['Body'].read().decode('utf-8'))

    newfilelist = []
    dest = 'manifest/%s' % today_timestamp
    for file in manifest['files']:
        newkey = "%s/%s" % (dest, file['key'].split('/')[-1])
        s3.Object(bucket_name, newkey).copy_from(CopySource={
            "Bucket" : bucket_name,
            "Key": file['key']
        })
        file['key'] = newkey
        newfilelist.append(file)
    
    manifest['files'] = newfilelist
    manifest_dest = "%s/manifest.json" % dest

    new_manifest = s3.Object(bucket_name, manifest_dest)
    new_manifest.put(
        Body=json.dumps(manifest).encode('utf-8'),
        ContentEncoding='utf-8',
        ContentType='application/json')


def aws_lambda_handeler(event, context):
    for bucket in ['mogreps-g', 'mogreps-uk']:
        manifest_for_bucket(bucket)
        logging.info('Done: %s' % bucket)
    return {'result':'done'}


if __name__ == "__main__" :
    
    aws_lambda_handeler({},{})