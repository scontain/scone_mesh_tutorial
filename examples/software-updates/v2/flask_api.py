import os

from flask import Flask


app = Flask(__name__)
API_VERSION = "v2"


@app.route("/")
def hello_world():
  return "Hello, World!"


@app.route("/version")
def api_version():
  return API_VERSION


if __name__ == '__main__':
    app.debug = False
    app.run(host='0.0.0.0', port=5000)
