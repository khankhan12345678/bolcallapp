import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BolCallApp());
}

class BolCallApp extends StatelessWidget {
  const BolCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bol Call - Voice Dialer & Anti-Theft',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD97706),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;
  bool isPremium = false;
  int premiumDaysRemaining = 0;
  bool autoSpeakerEnabled = true;
  String currentLanguage = 'en'; // 'en', 'ur', 'hi'

  // Anti-Theft State
  bool isAntiTheftArmed = false;
  bool motionDetectionEnabled = true;
  bool pocketModeEnabled = true;
  bool chargerAlarmEnabled = true;
  bool isAlarmTriggered = false;
  String alarmReason = '';
  String pinCode = '1234';

  // Voice & TTS
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  String _voiceTranscript = '';

  // Contacts
  final List<Map<String, String>> contacts = [
    {
      'id': '1',
      'name': 'Mom (امی)',
      'phone': '+91 98765 43210',
      'category': 'Family',
      'photo': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&h=200&fit=crop'
    },
    {
      'id': '2',
      'name': 'Dad (ابو)',
      'phone': '+91 98765 12345',
      'category': 'Family',
      'photo': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop'
    },
    {
      'id': '3',
      'name': 'Sarah Khan',
      'phone': '+91 98111 22334',
      'category': 'Friends',
      'photo': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop'
    },
    {
      'id': '4',
      'name': 'Emergency Helpline',
      'phone': '112',
      'category': 'Emergency',
      'photo': 'https://images.unsplash.com/photo-1516549655169-df83a0774514?w=200&h=200&fit=crop'
    },
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();
    _listenMotionSensor();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.9);
  }

  void _listenMotionSensor() {
    accelerometerEvents.listen((AccelerometerEvent event) {
      if (!isAntiTheftArmed || !motionDetectionEnabled || isAlarmTriggered) return;
      double totalAcc = event.x.abs() + event.y.abs() + (event.z.abs() - 9.8).abs();
      if (totalAcc > 5.5) {
        _triggerAlarm("Motion Detected! Phone was picked up or moved.");
      }
    });
  }

  void _triggerAlarm(String reason) {
    setState(() {
      isAlarmTriggered = true;
      alarmReason = reason;
    });
    _speak("Warning! Anti Theft Alarm Triggered! Please enter PIN code to disarm.");
  }

  void _disarmAlarm() {
    setState(() {
      isAlarmTriggered = false;
      alarmReason = '';
    });
    _speak("Alarm disarmed successfully.");
  }

  void _speak(String text) async {
    if (currentLanguage == 'ur') {
      await _flutterTts.setLanguage("ur-PK");
    } else if (currentLanguage == 'hi') {
      await _flutterTts.setLanguage("hi-IN");
    } else {
      await _flutterTts.setLanguage("en-US");
    }
    await _flutterTts.speak(text);
  }

  void _dialNumber(String phone, String name) async {
    _speak("Bol Call: Calling $name");
    final Uri url = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s+'), ''));
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _startVoiceListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('status: $status'),
      onError: (errorNotification) => print('error: $errorNotification'),
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _voiceTranscript = result.recognizedWords;
          });
          if (result.finalResult) {
            setState(() => _isListening = false);
            _processVoiceCommand(_voiceTranscript);
          }
        },
      );
    }
  }

  void _processVoiceCommand(String text) {
    String lower = text.toLowerCase();
    for (var c in contacts) {
      if (lower.contains(c['name']!.toLowerCase().split(' ')[0])) {
        _dialNumber(c['phone']!, c['name']!);
        return;
      }
    }
    _speak("Could not match contact for $text. Please try again.");
  }

  void _showPremiumPassDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1917),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Anti-Theft Premium Pass', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unlock Motion Detection, Pocket Mode, Charger Alarm, Fingerprint Lock & Remove all Google AdMob ads!',
              style: TextStyle(color: Color(0xFFA8A29E), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF292524),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD97706)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('50-Day Pass (Best Value)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('Just ₹1 / day for 50 days', style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                    ],
                  ),
                  Text('₹50', style: TextStyle(color: Color(0xFFD97706), fontSize: 24, fontWeight: FontWeight.black)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            onPressed: () {
              setState(() {
                isPremium = true;
                premiumDaysRemaining = 50;
                isAntiTheftArmed = true;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('50-Day Premium Pass Activated! Google Ads Removed.')),
              );
            },
            child: const Text('Activate Pass (₹50)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            title: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFFD97706),
                  radius: 16,
                  child: Text('B', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 8),
                Text('Bol Call', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.language, color: Color(0xFFD97706)),
                onPressed: () {
                  setState(() {
                    currentLanguage = currentLanguage == 'en' ? 'ur' : (currentLanguage == 'ur' ? 'hi' : 'en');
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Language switched to $currentLanguage')),
                  );
                },
              ),
              if (!isPremium)
                TextButton.icon(
                  onPressed: _showPremiumPassDialog,
                  icon: const Icon(Icons.star, color: Color(0xFFD97706), size: 16),
                  label: const Text('₹50 Pass', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    _buildKeypadTab(),
                    _buildVoiceTab(),
                    _buildPhotoCallingTab(),
                    _buildContactsTab(),
                    _buildSecurityTab(),
                  ],
                ),
              ),
              // AdMob Banner (Free Version Only)
              if (!isPremium) _buildAdMobBanner(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dialpad), label: 'Keypad'),
              NavigationDestination(icon: Icon(Icons.mic), label: 'Voice'),
              NavigationDestination(icon: Icon(Icons.photo_library), label: 'Photos'),
              NavigationDestination(icon: Icon(Icons.contacts), label: 'Contacts'),
              NavigationDestination(icon: Icon(Icons.shield), label: 'Security'),
            ],
          ),
        ),

        // Urgent Intruder Siren Screen Overlay
        if (isAlarmTriggered) _buildIntruderAlarmScreen(),
      ],
    );
  }

  Widget _buildKeypadTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Bol Call Numbers Dialer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'].map((d) {
            return SizedBox(
              width: 72,
              height: 72,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 1,
                ),
                onPressed: () {},
                child: Text(d, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        FloatingActionButton.extended(
          backgroundColor: const Color(0xFF10B981),
          onPressed: () => _dialNumber(contacts[0]['phone']!, contacts[0]['name']!),
          icon: const Icon(Icons.phone, color: Colors.white),
          label: const Text('Call', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  Widget _buildVoiceTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: _isListening ? Colors.amber : const Color(0xFFD97706),
            child: IconButton(
              iconSize: 48,
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.black),
              onPressed: _startVoiceListening,
            ),
          ),
          const SizedBox(height: 16),
          Text(_isListening ? 'Listening...' : 'Tap mic and say "Call Mom"', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (_voiceTranscript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('"$_voiceTranscript"', style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoCallingTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: contacts.length,
      itemTile: (ctx, i) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: () => _dialNumber(contacts[i]['phone']!, contacts[i]['name']!),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 36, backgroundImage: NetworkImage(contacts[i]['photo']!)),
              const SizedBox(height: 8),
              Text(contacts[i]['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(contacts[i]['category']!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactsTab() {
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (ctx, i) => ListTile(
        leading: CircleAvatar(backgroundImage: NetworkImage(contacts[i]['photo']!)),
        title: Text(contacts[i]['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(contacts[i]['phone']!),
        trailing: IconButton(
          icon: const Icon(Icons.phone, color: Colors.green),
          onPressed: () => _dialNumber(contacts[i]['phone']!, contacts[i]['name']!),
        ),
      ),
    );
  }

  Widget _buildSecurityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Anti-Theft Master Guard', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Alarms if moved, unplugged or pulled from pocket'),
          value: isAntiTheftArmed,
          onChanged: (val) {
            if (!isPremium) {
              _showPremiumPassDialog();
            } else {
              setState(() => isAntiTheftArmed = val);
            }
          },
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('Motion Detection Sensor'),
          subtitle: const Text('Triggers siren when phone is moved from surface'),
          value: motionDetectionEnabled,
          onChanged: (val) => setState(() => motionDetectionEnabled = val),
        ),
        SwitchListTile(
          title: const Text('Pocket Mode (Proximity)'),
          subtitle: const Text('Alerts if taken out of pocket/bag'),
          value: pocketModeEnabled,
          onChanged: (val) => setState(() => pocketModeEnabled = val),
        ),
        SwitchListTile(
          title: const Text('Charger Alarm'),
          subtitle: const Text('Siren sounds if power cord is unplugged'),
          value: chargerAlarmEnabled,
          onChanged: (val) => setState(() => chargerAlarmEnabled = val),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => _triggerAlarm("Simulated Motion Alert!"),
          icon: const Icon(Icons.warning, color: Colors.white),
          label: const Text('Test Siren Alarm (Demo)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  Widget _buildAdMobBanner() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Google AdMob: 5G SIM Deals', style: TextStyle(color: Colors.white, fontSize: 12)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), padding: const EdgeInsets.symmetric(horizontal: 10)),
            onPressed: _showPremiumPassDialog,
            child: const Text('Remove Ads (₹50)', style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildIntruderAlarmScreen() {
    return Container(
      color: Colors.red.withOpacity(0.95),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.white),
            const SizedBox(height: 16),
            const Text('ANTI-THEFT ALARM!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(alarmReason, style: const TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
              onPressed: _disarmAlarm,
              child: const Text('Disarm with PIN (1234)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}
