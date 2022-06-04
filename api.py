from flask import Flask, request, jsonify, Response
from flask_restful import Resource, Api
import json
import os
import random
import redis
import sys, os, re
import time
import socket

from schwifty import IBAN

app = Flask(__name__)
api = Api(app)


# Setup redis instance.
REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = os.environ.get("REDIS_PORT", 6379)
print("Connecting to DB ", REDIS_HOST, REDIS_PORT, flush=True)

db = redis.StrictRedis(
   host=REDIS_HOST,
   port=REDIS_PORT,
   ssl=True,
   ssl_keyfile='/tls/client.key',
   ssl_certfile='/tls/client.crt',
   ssl_cert_reqs="required",
   ssl_ca_certs='/tls/redis-ca.crt')

# Test connection to redis (break if the connection fails).
time.sleep(5)
data = socket.gethostbyname_ex(REDIS_HOST)
print ("The IP Address of redis host is: "+repr(data))  
db.info()
print("Connection to DB is fine", flush=True)

class Client(Resource):
    def get(self, client_id):
        client_data = db.get(client_id)
        if client_data is not None:
            decoded_data = json.loads(client_data.decode('utf-8'))
            decoded_data["id"] = client_id
            return jsonify(decoded_data)
        return Response({"error": "unknown client_id"}, status=404, mimetype='application/json')

    def post(self, client_id):
        if db.exists(client_id):
            return Response({"error": "already exists"}, status=403, mimetype='application/json')
        else:
            # convert client data to binary.
            client_data = json.dumps({
            "fname": request.form['fname'],
            "lname": request.form['lname'],
            "address": request.form['address'],
            "city": request.form['city'],
            "iban": request.form['iban'],
            "ssn": request.form['ssn'],
            "email": request.form['email'],
            "score": random.random()
            }).encode('utf-8')
            try:
                db.set(client_id, client_data)
            except Exception as e:
                print(e)
                return Response({"error": "internal server error"}, status=500, mimetype='application/json')
            client_data = json.loads(client_data.decode('utf-8'))
            client_data["id"] = client_id
            return jsonify(client_data)


class Score(Resource):
    def get(self, client_id):
        client_data = db.get(client_id)
        if client_data is not None:
            score = json.loads(client_data.decode('utf-8'))["score"]
            return jsonify({"id": client_id, "score": score})
        return Response({"error": "unknown client"}, status=404, mimetype='application/json')


class Listkeys(Resource):
    def get(self):
        all_keys = db.keys(pattern="*")
        if all_keys is not None:
            all_data = [db.get(k) for k in all_keys]
            all_data_d = [json.loads(v.decode('utf-8')) for v in all_data]
            score = json.dumps(all_data_d)
            return jsonify({"keys": all_data_d})
        return Response({"error": "no keys"}, status=404, mimetype='application/json')

class DumpMemory(Resource):
    def get(self):
        pid = os.getpid()
        print("PID = %s \n" % pid)
        maps_file = open("/proc/%s/maps" % pid, 'r')
        mem_file= open("/proc/%s/mem" % pid, 'rb')
        
        for line in maps_file.readlines():
            m = re.match(r'([0-9A-Fa-f]+)-([0-9A-Fa-f]+) ([-r][-w])', line)
            if m.group(3) == "rw" or m.group(3) == "r-" :
                try:
                    start = int(m.group(1), 16)
                    if start > 0xFFFFFFFFFFFF:
                        continue
                    print("\nOK : \n" + line+"\n")
                    end = int(m.group(2), 16)
                    mem_file.seek(start) 
                    chunk = mem_file.read(end - start)
                    print(chunk)
                    sys.stdout.flush()
                except Exception as e:
                    print(str(e))  
            else:
                print("\nPASS : \n" + line+"\n") 
        print("END")


api.add_resource(Client, '/client/<string:client_id>')
api.add_resource(Score, '/score/<string:client_id>')
api.add_resource(Listkeys, '/keys')
api.add_resource(DumpMemory, '/memory')


if __name__ == '__main__':
    app.debug = True
    print("Starting Flask...", flush=True)
    app.run(host='0.0.0.0', port=4996, use_reloader=False, threaded=True, ssl_context=(("/tls/flask.crt", "/tls/flask.key")))
