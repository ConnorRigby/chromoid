package id.chromo.link

import android.graphics.Color
import android.os.Bundle
import android.widget.Button
import androidx.appcompat.app.AppCompatActivity
import ch.kuon.phoenix.Socket

fun socketInit(mainActivity: MainActivity) {


    val opts = Socket.Options()
    opts.timeout = 5_000
    opts.heartbeatIntervalMs = 10_000
    opts.rejoinAfterMs = { tries -> tries * 500}
    opts.reconnectAfterMs = { tries -> tries * 500}
    opts.params = HashMap<String, Any> ()

    val url = "ws://10.0.2.2:4000/device_socket" // dev
    opts.params?.set("token", "m_CVZWnscA-eyajZzx180YBQNnII2bXa4hv1JrLqwRw") // dev

    //val url = "wss://chromo.id/device_socket" // prod
    //opts.params?.set("token", "DGR_xUctGXrVHhxrVDaPHQu5rMYOxuN1lAJCUkr1U4k") // prod


    val socket = Socket(url, opts)
    val button = mainActivity.findViewById<Button>(R.id.connectButton)
    button.text = "Initializing...";

    socket.onError {
        println("There was an error with the connection!")
    }
    socket.onClose { i: Int, s: String -> println("The connection closed!") }
    socket.connect()

    val chan = socket.channel("device")
    var changeText = { value: String, color: Int ->
        button.text = value
        button.setBackgroundColor(color)
    }

    chan
    .join()
    .receive("ok") { msg ->
        println("Connected to device channel " + mainActivity.getString(R.string.connectionOK))
        changeText(mainActivity.getString(R.string.connectionOK), Color.GREEN)
    }
    .receive("error") { msg ->
        changeText(R.string.connectionErr.toString(), Color.RED)
    }
    .receive("timeout") { msg ->
        changeText(R.string.connectionErrTimeout.toString(), Color.YELLOW)
    }
}

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        val button = findViewById<Button>(R.id.connectButton)
        button?.setOnClickListener()
        {
            socketInit(this)
        }
    }
}
