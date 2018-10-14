#include <Zmq/Zmq.mqh>
#include <json.mqh>
#include <mql4_migration.mqh>
#include <operations.mqh>

extern string PROJECT_NAME = "zeromq_server";
extern string ZEROMQ_PROTOCOL = "tcp";
extern string HOSTNAME = "*";
extern int REP_PORT = 5555;
extern int PUSH_PORT = 5556;
extern int TIMER_PERIOD_MS = 5000;

Context context(PROJECT_NAME);

Operations op(&context);

int OnInit() {
  EventSetMillisecondTimer(TIMER_PERIOD_MS);
  op.setup_server(ZEROMQ_PROTOCOL, HOSTNAME, REP_PORT, PUSH_PORT);
  return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
  op.close_server(ZEROMQ_PROTOCOL, HOSTNAME, REP_PORT, PUSH_PORT);
}

void OnTimer() {
  ZmqMsg msg_container;
  op.listen_to_requests(msg_container);
  string reply = on_incomming_message(msg_container);
  op.reply_to_requests(reply);
}

string on_incomming_message(ZmqMsg &client_request) {
  uchar _data[];
  JSONParser *json_parser = new JSONParser();
  JSONValue *json_value;
  string reply;

  if (client_request.size() > 0) {
    if (ArrayResize(_data, (int)client_request.size(), 0) != EMPTY) {
      client_request.getData(_data);
      string data_str = CharArrayToString(_data);
      json_value = json_parser.parse(data_str);

      if (json_value == NULL) {
        Print("Coudn't parse: " + (string)json_parser.getErrorCode() +
              (string)json_parser.getErrorMessage());
      } else {
        JSONObject *json_object = json_value;
        reply = handle_zmq_msg(json_object);
        delete json_value;
      }
    }
  }
  delete json_parser;
  return reply;
}

string handle_zmq_msg(JSONObject *&json_object) {
  string op_code = json_object["operation"];
  string reply;
  if (op_code == "trade") {
    op.handle_trade_operations(json_object);
  } else if (op_code == "rates") {
    op.handle_rate_operations(json_object);
  } else if (op_code == "data") {
    reply = op.handle_data_operations(json_object);
  }
  return reply;
}