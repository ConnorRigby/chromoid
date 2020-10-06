package id.chromo.link

import android.app.NotificationManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.Button
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import ch.kuon.phoenix.Channel
import com.google.android.material.card.MaterialCardView
import kotlinx.android.synthetic.main.my_text_view.view.*
import ch.kuon.phoenix.Socket

public class BLEConn(socket: Socket, device: BluetoothDevice) {
    val device = device;
    private val socket = socket;
    private val chan = socket.channel("ble:" + device.address)
    public fun init() {
        chan
            .join()
            .receive("ok") { msg ->
                Log.i("ble:" + device.address, "Channel connected")
            }
            .receive("error") { msg ->
                Log.e("ble:" + device.address, "Device Channel error")
            }
    }

    public fun deinit() {
        chan.leave()
    }
}

class MyAdapter(private val myDataset: ArrayList<BLEConn>) :
    RecyclerView.Adapter<MyAdapter.MyViewHolder>() {

    // Provide a reference to the views for each data item
    // Complex data items may need more than one view per item, and
    // you provide access to all the views for a data item in a view holder.
    // Each data item is just a string in this case that is shown in a TextView.
    class MyViewHolder(val textView: MaterialCardView) : RecyclerView.ViewHolder(textView)

    // Create new views (invoked by the layout manager)
    override fun onCreateViewHolder(
        parent: ViewGroup,
        viewType: Int
    ): MyAdapter.MyViewHolder {
        // create a new view
        val textView = LayoutInflater.from(parent.context)
            .inflate(R.layout.my_text_view, parent, false) as MaterialCardView
        // set the view's size, margins, paddings and layout parameters
        return MyViewHolder(textView)
    }

    // Replace the contents of a view (invoked by the layout manager)
    override fun onBindViewHolder(holder: MyViewHolder, position: Int) {
        // - get element from your dataset at this position
        // - replace the contents of the view with that element
        //holder.textView.text = myDataset[position]
        holder.textView.cardtitle.text = myDataset[position].device.address
    }

    // Return the size of your dataset (invoked by the layout manager)
    override fun getItemCount() = myDataset.size
}


class MainActivity : AppCompatActivity() {
    private lateinit var recyclerView: RecyclerView
    private lateinit var viewAdapter: RecyclerView.Adapter<*>
    private lateinit var viewManager: RecyclerView.LayoutManager
    lateinit var myDataset: ArrayList<BLEConn>
    private val REQUEST_ENABLE_BT = 1
    private lateinit var socket : Socket;
    private var socketOpts = Socket.Options()
    private lateinit var deviceChannel: Channel

    // dev
    //private val socketURL = "ws://10.0.2.2:4000/device_socket"
    //private val socketToken = "m_CVZWnscA-eyajZzx180YBQNnII2bXa4hv1JrLqwRw"

    // prod
    private val socketURL = "wss://chromo.id/device_socket"
    private val socketToken = "DGR_xUctGXrVHhxrVDaPHQu5rMYOxuN1lAJCUkr1U4k"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Initialize socket
        Log.i("Socket", "initializing socketOpts")
        socketOpts.timeout = 5_000
        socketOpts.heartbeatIntervalMs = 10_000
        socketOpts.rejoinAfterMs = { tries -> tries * 500}
        socketOpts.reconnectAfterMs = { tries -> tries * 500}
        socketOpts.params = hashMapOf("token" to socketToken)
        Log.i("Socket", "initializing socket")
        socket = Socket(socketURL, socketOpts)
        socket.onError {
            Log.e("Socket", "There was an error with the connection!")
        }
        socket.onClose { _, s: String ->
            Log.w("Socket", "Socket disconnected: $s")
        }
        // Connect to socket
        Log.i("Socket", "connecting socket")
        socket.connect()
        deviceChannel = socket.channel("device")
        deviceChannel
            .join()
            .receive("ok") { msg ->
                Log.i("DEVICECHANNNEL", "Device Channel connected")
            }
            .receive("error") { msg ->
                Log.e("DEVICECHANNNEL", "Device Channel error")
            }

        // Initialize card view
        viewManager = LinearLayoutManager(this)
        myDataset = arrayListOf()
        viewAdapter = MyAdapter(myDataset)

        recyclerView = findViewById<RecyclerView>(R.id.my_recycler_view).apply {
            // use this setting to improve performance if you know that changes
            // in content do not change the layout size of the RecyclerView
            setHasFixedSize(true)

            // use a linear layout manager
            layoutManager = viewManager

            // specify an viewAdapter (see also next example)
            adapter = viewAdapter

        }

        // Initializes Bluetooth adapter.
        val bluetoothManager = getSystemService(BLUETOOTH_SERVICE) as BluetoothManager
        val bluetoothAdapter = bluetoothManager.adapter
        // Ensures Bluetooth is available on the device and it is enabled. If not,
        // displays a dialog requesting user permission to enable Bluetooth.
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
            startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT)
        }

        val bluetoothLeScanner = BluetoothAdapter.getDefaultAdapter().bluetoothLeScanner
        val button: Button = findViewById(R.id.add_button)
        button.setOnClickListener {
            bluetoothLeScanner.startScan(leScanCallback)
        }
        //startService()
    }
    private val leScanCallback: ScanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            super.onScanResult(callbackType, result)
//            Log.i("leScanCallback", "New ScanResult")
//            val dev = BLEConn(socket, result.device)
//            dev.init()
//            myDataset.add(0, dev)
//            viewAdapter.notifyItemInserted(0);
        }
    }

    override fun onDestroy() {
//        stopService()
        socket.disconnect()
        super.onDestroy()
    }

    private fun startService() {
        val serviceIntent = Intent(this, ForegroundService::class.java)
        serviceIntent.putExtra("inputExtra", "Foreground Service Example in Android")
        ContextCompat.startForegroundService(this, serviceIntent)
    }

    private fun stopService() {
        val serviceIntent = Intent(this, ForegroundService::class.java)
        stopService(serviceIntent)
    }
}
