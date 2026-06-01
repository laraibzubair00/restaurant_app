import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() => runApp(MaterialApp(
      title: 'Nimbus Restaurant Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6200EE)),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      ),
      home: const MainNavigation(),
    ));

const String baseUrl = "http://62.171.178.56/reservation/php"; 

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  List reservations = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchReservations();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (t) => fetchReservations());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchReservations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_reservations.php'));
      if (response.statusCode == 200) {
        setState(() {
          reservations = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
  }

  Future<void> updateStatus(BuildContext context, String id, String status) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_status.php'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id": id, "status": status}),
      );
      
      var result = json.decode(response.body);
      if (result['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Customer $status successfully"), backgroundColor: Colors.green),
        );
        fetchReservations(); 
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      ManagerDashboard(
        reservations: reservations, 
        updateStatus: updateStatus, 
        fetchReservations: fetchReservations
      ),
      HistoryScreen(reservations: reservations),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Live Dashboard'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History & Reports'),
        ],
      ),
    );
  }
}

class ManagerDashboard extends StatelessWidget {
  final List reservations;
  final Function updateStatus;
  final Function fetchReservations;

  const ManagerDashboard({super.key, required this.reservations, required this.updateStatus, required this.fetchReservations});

  void _showAddManualEntry(BuildContext context, String type) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final sizeCtrl = TextEditingController();
    String selectedSlot = "7:00 PM";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Add Manual $type"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Full Name")),
              TextField(
                controller: phoneCtrl, 
                decoration: const InputDecoration(labelText: "Phone Number"),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              TextField(
                controller: sizeCtrl, 
                decoration: const InputDecoration(labelText: "Party Size"), 
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              if (type == 'booking')
                DropdownButton<String>(
                  value: selectedSlot,
                  isExpanded: true,
                  items: ["12:00 PM", "1:00 PM", "2:00 PM", "7:00 PM", "8:00 PM", "9:00 PM"]
                      .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setDialogState(() => selectedSlot = val!),
                )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                await http.post(
                  Uri.parse('$baseUrl/add_reservation.php'), 
                  headers: {"Content-Type": "application/json"},
                  body: json.encode({
                    "name": nameCtrl.text,
                    "phone": phoneCtrl.text,
                    "party_size": sizeCtrl.text,
                    "type": type,
                    "booking_time": type == 'booking' ? selectedSlot : 'NOW'
                  })
                );
                fetchReservations();
                Navigator.pop(context);
              },
              child: const Text("Add Customer"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isLive(dynamic r) {
      var s = r['status']?.toString().toLowerCase();
      return s == 'pending' || s == '' || s == null;
    }

    var bookings = reservations.where((r) => (r['type'] == 'booking' || r['visit_type'] == 'booking') && isLive(r)).toList();
    var waitlist = reservations.where((r) => (r['type'] == 'waitlist' || r['visit_type'] == 'waitlist') && isLive(r)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nimbus Dashboard", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 22), onPressed: () => fetchReservations()),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CustomerTrackerScreen(activeWaitlist: waitlist))),
            icon: const Icon(Icons.track_changes, size: 18),
            label: const Text("Tracker", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                _statChip("Bookings", bookings.length, Colors.blue),
                const SizedBox(width: 6),
                _statChip("Waitlist", waitlist.length, Colors.orange),
                const Spacer(),
                const Icon(Icons.circle, color: Colors.green, size: 8),
                const SizedBox(width: 4),
                const Text("LIVE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  _buildColumn(context, "Bookings", bookings, "booking"),
                  const SizedBox(width: 8),
                  _buildColumn(context, "Waitlist", waitlist, "waitlist"),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _statChip(String label, int val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text("$label: $val", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildColumn(BuildContext context, String title, List items, String typeKey) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.add_circle, color: Color(0xFF6200EE), size: 24),
                  onPressed: () => _showAddManualEntry(context, typeKey),
                ),
              ],
            ),
            const Divider(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  var res = items[index];
                  var currentType = res['type'] ?? res['visit_type'] ?? 'booking';
                  String timeLabel = currentType == 'booking' 
                      ? "⏰ ${res['booking_time'] ?? 'NOW'}" 
                      : "🕒 ${res['created_at'] != null ? res['created_at'].toString().split(' ')[1].substring(0,5) : 'NOW'}";

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            res['name'] ?? res['customer_name'] ?? 'No Name', 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "📞 ${res['phone'] ?? res['phone_number'] ?? 'N/A'}", 
                            style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Size: ${res['party_size']} | $timeLabel",
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => updateStatus(context, res['id'].toString(), 'cancelled'),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => updateStatus(context, res['id'].toString(), 'seated'),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: const Color(0xFF6200EE), borderRadius: BorderRadius.circular(6)),
                                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  final List reservations;
  // FIXED CONSTRUCTOR: Included required reservations parameter
  const HistoryScreen({super.key, required this.reservations});

  @override
  Widget build(BuildContext context) {
    int total = reservations.length;
    int seated = reservations.where((r) => r['status'].toString().toLowerCase() == 'seated').length;
    int cancelled = reservations.where((r) => r['status'].toString().toLowerCase() == 'cancelled').length;

    return Scaffold(
      appBar: AppBar(title: const Text("History & Reports", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                _reportBox("Total", total, Colors.blue),
                _reportBox("Seated", seated, Colors.green),
                _reportBox("Cancelled", cancelled, Colors.red),
              ],
            ),
            const SizedBox(height: 15),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: reservations.length,
                itemBuilder: (context, index) {
                  var res = reservations[index];
                  String stat = (res['status'] == null || res['status'] == '' || res['status'] == 'pending') ? 'PENDING' : res['status'].toString().toUpperCase();
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(res['name'] ?? res['customer_name'] ?? 'No Name', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      "${res['type'] ?? res['visit_type'] ?? ''} | ${res['phone'] ?? res['phone_number'] ?? ''}",
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Text(stat, 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10,
                        color: stat == 'SEATED' ? Colors.green : (stat == 'CANCELLED' ? Colors.red : Colors.blue))),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _reportBox(String title, int val, Color color) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
          child: Column(
            children: [
              Text(
                title, 
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
              const SizedBox(height: 4),
              Text("$val", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerTrackerScreen extends StatefulWidget {
  final List activeWaitlist;
  const CustomerTrackerScreen({super.key, required this.activeWaitlist});
  @override
  State<CustomerTrackerScreen> createState() => _CustomerTrackerScreenState();
}

class _CustomerTrackerScreenState extends State<CustomerTrackerScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Map? _found;
  int _pos = -1;

  void _search() {
    for (int i = 0; i < widget.activeWaitlist.length; i++) {
      var currentPhone = widget.activeWaitlist[i]['phone'] ?? widget.activeWaitlist[i]['phone_number'] ?? '';
      if (currentPhone.toString().contains(_searchCtrl.text)) {
        setState(() { _found = widget.activeWaitlist[i]; _pos = i + 1; });
        return;
      }
    }
    setState(() { _found = null; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Status Tracker")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl, 
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: "Enter Phone Number", 
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search)
              ),
            ),
            if (_found != null) ...[
              const SizedBox(height: 40),
              Text("Hello, ${_found!['name'] ?? _found!['customer_name'] ?? ''}", style: const TextStyle(fontSize: 20)),
              Text("$_pos", style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.blue)),
              const Text("Your Queue Position"),
            ]
          ],
        ),
      ),
    );
  }
}