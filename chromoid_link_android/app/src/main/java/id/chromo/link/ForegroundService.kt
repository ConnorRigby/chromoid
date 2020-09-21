package id.chromo.link

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import ch.kuon.phoenix.Socket
import android.util.Log

private const val LOG_TAG = "ForegroundService"

public class ForegroundService : Service() {
    private val serviceChannelID = "ForegroundServiceChannel"
    private var socket : Socket? = null;
    private var socketOpts = Socket.Options()

    // dev
    private val socketURL = "ws://10.0.2.2:4000/device_socket"
    private val socketToken = "m_CVZWnscA-eyajZzx180YBQNnII2bXa4hv1JrLqwRw"

    // prod
    // private val socketURL = "wss://chromo.id/device_socket"
    // private val socketToken = "DGR_xUctGXrVHhxrVDaPHQu5rMYOxuN1lAJCUkr1U4k"

    override fun onCreate() {
        socketOpts.timeout = 5_000
        socketOpts.heartbeatIntervalMs = 10_000
        socketOpts.rejoinAfterMs = { tries -> tries * 500}
        socketOpts.reconnectAfterMs = { tries -> tries * 500}
        socketOpts.params = HashMap<String, Any> ()
        socketOpts.params?.set("token", socketToken)
        socket = Socket(socketURL, socketOpts)
        socket?.onError {
            Log.e(LOG_TAG, "There was an error with the connection!")
        }
        socket?.onClose { i: Int, s: String ->
            Log.w(LOG_TAG, "Socket disconnected")
        }
        super.onCreate()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val input = intent!!.getStringExtra("inputExtra")
        createNotificationChannel()
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0, notificationIntent, 0
        )
        val notificationBuilder = NotificationCompat.Builder(this, serviceChannelID)
            .setContentTitle("Foreground Service")
            .setContentText(input)
            .setContentIntent(pendingIntent)

        startForeground(1, notificationBuilder.build())
        socket?.connect()
        val chan = socket?.channel("device")
        chan!!
            .join()
            .receive("ok") { msg ->
                Log.i(LOG_TAG, "Device Channel connected")
                val manager = getSystemService(NotificationManager::class.java)
                notificationBuilder.setContentTitle("Connected!")
                manager.notify(1, notificationBuilder.build())
            }
            .receive("error") { msg ->
                Log.e(LOG_TAG, "Device Channel error")
                val manager = getSystemService(NotificationManager::class.java)
                notificationBuilder.setContentTitle("Channel connection error!")
                manager.notify(1, notificationBuilder.build())
            }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        TODO("Not yet implemented")
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                serviceChannelID,
                "Chromo.id Socket Connection",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(
                NotificationManager::class.java
            )
            manager.createNotificationChannel(serviceChannel)
        }
    }
}