package id.chromo.link

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle

import ch.kuon.phoenix.Socket
import ch.kuon.phoenix.Channel
import ch.kuon.phoenix.Presence


fun doSomething() {
    val url = "ws://localhost:4000/device_socket/websocket?token=gQwn5GgQ8rExwlb_naec_60Tc_FVWROj5lrBxs9Cm60"
    val sd = Socket(url)

    sd.connect()

    val chan = sd.channel("devices")

    chan
    .join()
    .receive("ok") { msg ->
        // channel is connected
    }
    .receive("error") { msg ->
        // channel did not connected
    }
    .receive("timeout") { msg ->
        // connection timeout
    }

    chan
    .push("hello")
    .receive("ok") { msg ->
        // sent hello and got msg back
    }

}

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
    }
}
