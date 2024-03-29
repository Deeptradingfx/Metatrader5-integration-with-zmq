import logging as log
from multiprocessing import Lock
from multiprocessing import Event
from multiprocessing import Process
from multiprocessing.pool import ThreadPool
from bal.callback_utils import ThreadPoolWithError


class Subscriptions():
    def __init__(self):
        self._subscriber_dict = {}
        self._subscribers_lock = Lock()

    def _gather_subscriptions(self, server_closed):
        _thread_pool = ThreadPoolWithError()
        while not server_closed.is_set():
            published_data = self._socket_sub.recv_json()
            log.info('Received publication.')

            _thread_pool.apply_async(
                self._notify_subscribers,
                args=(published_data,)
            )

    def add_subscription(self, symbol, callback, timeframe_events):
        with self._subscribers_lock:
            if symbol in self._subscriber_dict.keys():
                log.warning(
                    'Symbol already has a callback. Replacing the first one')
            self._subscriber_dict[symbol] = {
                'callback': callback, 'timeframe_events': timeframe_events}

    def remove_subscription(self, symbol):
        with self._subscribers_lock:
            self._subscriber_dict.pop(symbol, None)

    def _notify_subscribers(self, subscription_data):
        with self._subscribers_lock:
            rec_symbol = subscription_data['symbol']
            self._subscriber_dict[rec_symbol]['callback'](
                (subscription_data['time'], subscription_data['price']))

    def setup_comunication(self):
        self._server_closed = Event()
        self._subscription_thread_pool = ThreadPool(1)
        process = Process(target=self._gather_subscriptions,
                          args=(self._server_closed,
                                self._subscription_thread_pool),
                          daemon=True)
        process.start()

    def close_server(self):
        self._server_closed.set()
