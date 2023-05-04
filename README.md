

## Clone and Run locally

###  Create Virtual env

 > !NOTE
 > Needs to be named **`antenv`** for app service to locate it!

```
$ python3 -m venv antenv
$ source antenv/bin/activate
```

 > !NOTE To deactivate 
 > `$ deactivate`



### Install some test packages in the virtual env

```
python -m pip install -r requirements.txt
```

###  Create a demo app.py

```
echo "import openai;
from flask import Flask

app = Flask(__name__)


@app.route('/')
def hello():
    return 'Hello, World, openai api_base=%s' % openai.api_base
" > app.py
```


## Run locally

```
flask run
```

#  Deploy to Azure 

## via Azure DevOps

### Pipelines included

* `azure-pipelines-build.yml` - application build pipeline
* `azure-pipelines-release.yml` - infra creation and app deployment

## via CLI

### Add app.py and the virtual environment to the zip file
zip -r ./release.zip app.py  antenv/

### Release to App Service
az webapp deploy -g rg -n appname --src-path ./release.zip

