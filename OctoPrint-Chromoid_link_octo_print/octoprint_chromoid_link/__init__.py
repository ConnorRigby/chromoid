from __future__ import absolute_import, unicode_literals
import octoprint.plugin

import threading
import time
import subprocess
import erlang
import os
import struct
import socket
import sys
from queue import Queue


class ChromoidLinkPlugin(octoprint.plugin.StartupPlugin,
                         octoprint.plugin.TemplatePlugin,
                         octoprint.plugin.SettingsPlugin,
                         octoprint.plugin.ProgressPlugin):

    def on_print_progress(self, storage, path, progress):
        term = (erlang.OtpErlangAtom(b'progress'),
                erlang.OtpErlangBinary(bytes(storage, "utf-8")),
                erlang.OtpErlangBinary(bytes(path, "utf-8")),
                progress
                )
        self.send(term, self.connection)

    def get_template_configs(self):
        return [
            # dict(type="navbar", custom_bindings=False),
            dict(type="settings", custom_bindings=False)
        ]

    def get_settings_defaults(self):
        return dict(url=None)

    def get_template_vars(self):
        return dict(url=self._settings.get(["url"]))

    def on_settings_save(self, data):
        old_url = self._settings.get(["url"])
        octoprint.plugin.SettingsPlugin.on_settings_save(self, data)
        new_url = self._settings.get(["url"])
        if old_url != new_url:
            self._logger.info(
                "url changed from {old_url} to {new_url}".format(**locals()))
            term = (erlang.OtpErlangAtom(bytes("url", "utf-8")),
                    erlang.OtpErlangBinary(bytes(new_url, "utf-8")))
            self.send(term, self.connection)

    def send(self, term, stream):
        """Write an Erlang term to an output stream."""
        payload = erlang.term_to_binary(term)
        header = struct.pack('!I', len(payload))
        stream.send(header)
        stream.send(payload)
        # stream.flush()

    def recv(self, stream):
        """Read an Erlang term from an input stream."""
        header = stream.recv(4)
        if len(header) != 4:
            return None  # EOF
        (length,) = struct.unpack('!I', header)
        payload = stream.recv(length)
        if len(payload) != length:
            return None
        term = erlang.binary_to_term(payload)
        return term

    def recv_loop(self, stream):
        """Yield Erlang terms from an input stream."""
        message = self.recv(stream)
        while message:
            yield message
            message = self.recv(stream)

    def erlang_subprocess_thread_function(self, name):
        # p = subprocess.Popen(['/home/connor/.asdf/shims/mix', 'run', '--no-halt'])
        # p = subprocess.Popen(['/home/connor/.asdf/shims/iex', '-S', 'mix'])
        # p = subprocess.Popen(['./_build/dev/rel/bakeware/chromoid_link_octo_print'])
        p = subprocess.Popen(['/home/pi/oprint/bin/chromoid_link_octo_print'])

        while True:
            if p.poll() != None:
                self._logger.error("Erlang exited")
                break
            data = self.queue.get()
            self.send(data, self.connection)

    def handle_erlang_log(self, level, message):
        # content = message[1][0].value
        content = message[1]
        if not isinstance(content, erlang.OtpErlangBinary):
            self._logger.error("unexpected content "+str(content))
            return

        # self._logger.debug("level=" + str(level))
        # self._logger.debug("message[1]=" + str(message[1]))
        if level == erlang.OtpErlangAtom(b'debug'):
            self._logger.debug(content.value.decode())
        elif level == erlang.OtpErlangAtom(b'info'):
            self._logger.info(content.value.decode())
        elif level == erlang.OtpErlangAtom(b'warn'):
            self._logger.warning(content.value.decode())
        elif level == erlang.OtpErlangAtom(b'error'):
            self._logger.error(content.value.decode())
        else:
            self._logger.error("unknown erlang logging level: " + str(level))

    def socket_thread_function(self, name):
        self._logger.info("Setting up socket")
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.bind((socket.gethostname(), 42069))
        self.sock.listen()
        self._logger.info("Waiting for connection")
        self.sock.settimeout(None)
        connection, _client_address = self.sock.accept()
        connection.settimeout(None)
        self.connection = connection
        self._logger.info("Connection established")
        url = self._settings.get(["url"])
        if url:
            self._logger.info("URL Configured")
            term = (erlang.OtpErlangAtom(bytes("url", "utf-8")),
                    erlang.OtpErlangBinary(bytes(url, "utf-8")))
            self.queue.put(term)

        for data in self.recv_loop(connection):
            if data[0] == erlang.OtpErlangAtom(bytes("logger", "utf-8")):
                # self._logger.info("handling log level="+str(message[1]) + " message=" + str(message[2]))
                self.handle_erlang_log(data[1], data[2])
            elif data[0] == erlang.OtpErlangAtom(b'ping'):
                self.send(erlang.OtpErlangAtom(b'pong'), connection)
            else:
                self._logger.error("unhandled message="+str(data))

            # self.send(message, connection)  # echo the message back

    def on_after_startup(self):
        self._logger.info("Booting Erlang")
        # self._settings.set([], None)
        self.queue = Queue()
        self.erlang_thread = threading.Thread(
            target=self.erlang_subprocess_thread_function, args=(1,))
        self.socket_thread = threading.Thread(
            target=self.socket_thread_function, args=(1,))
        self.erlang_thread.start()
        self.socket_thread.start()


__plugin_name__ = "chromoid_link"
__plugin_pythoncompat__ = ">=2.7,<4"
__plugin_implementation__ = ChromoidLinkPlugin()
