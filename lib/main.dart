import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const CommitteeApp());
}

const String baseUrl = 'https://committee-app-backend.onrender.com';

class CommitteeApp extends StatelessWidget {
  const CommitteeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Committee & Group Savings',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// =========================================================================
// सटीक Spin Wheel
// =========================================================================
class LotterySpinWheelDialog extends StatefulWidget {
  final List<dynamic> members;
  final Function(Map<String, dynamic> winnerMember) onWinnerSelected;

  const LotterySpinWheelDialog({
    super.key,
    required this.members,
    required this.onWinnerSelected,
  });

  @override
  State<LotterySpinWheelDialog> createState() => _LotterySpinWheelDialogState();
}

class _LotterySpinWheelDialogState extends State<LotterySpinWheelDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _selectedWinnerIndex = 0;
  bool _spinCompleted = false;
  bool _landedOnBorder = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _spinCompleted = true;
        });
        if (!_landedOnBorder && widget.members.isNotEmpty) {
          widget.onWinnerSelected(widget.members[_selectedWinnerIndex]);
        }
      }
    });

    _startNewSpin();
  }

  void _startNewSpin() {
    final int count = widget.members.isNotEmpty ? widget.members.length : 1;
    final rand = math.Random();
    _selectedWinnerIndex = rand.nextInt(count);

    final double sweepAngle = (2 * math.pi) / count;
    final bool simulateBorderHit = (count > 1) && (rand.nextInt(100) < 15);
    final double offsetInsideSegment = simulateBorderHit
        ? (sweepAngle * 0.02)
        : (sweepAngle * (0.25 + rand.nextDouble() * 0.50));

    final double hitAngle = (_selectedWinnerIndex * sweepAngle) + offsetInsideSegment;
    final double desiredFinalRotation = (-math.pi / 2) - hitAngle;
    final double normalizedTarget =
        (desiredFinalRotation % (2 * math.pi) + (2 * math.pi)) % (2 * math.pi);

    final double relativePosInSegment = offsetInsideSegment / sweepAngle;
    _landedOnBorder = (count > 1) && (relativePosInSegment < 0.06 || relativePosInSegment > 0.94);

    setState(() {
      _spinCompleted = false;
    });

    final double totalAngle = (12 * math.pi) + normalizedTarget;
    _animation = Tween<double>(begin: 0, end: totalAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.reset();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> names = widget.members
        .map((m) => (m['full_name'] ?? 'Member').toString())
        .toList();
    if (names.isEmpty) names.add('Member');

    final String winnerName = names[_selectedWinnerIndex];

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.casino, color: Colors.deepOrange),
          SizedBox(width: 8),
          Text('ग्रुप लॉटरी स्पिन (Spin Wheel)'),
        ],
      ),
      content: SizedBox(
        width: 330,
        height: 385,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_drop_down, size: 48, color: Colors.red),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animation.value,
                  child: CustomPaint(
                    size: const Size(235, 235),
                    painter: _WheelPainter(names: names),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (!_spinCompleted)
              const Text(
                'चक्का घूम रहा है... सुई जिस नाम के बीच रुकेगी वही विजेता होगा!',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo),
              )
            else if (_landedOnBorder)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade800),
                ),
                child: Column(
                  children: [
                    const Text(
                      '⚠️ सुई दो नामों के बीच (बॉर्डर लाइन) पर रुकी है!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _startNewSpin,
                      icon: const Icon(Icons.refresh),
                      label: const Text('दोबारा स्पिन करें (Re-Spin)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Text(
                  '🏆 विजेता घोषित: $winnerName\n(रिपोर्ट कार्ड में विजेता का नाम अपडेट हो गया है!)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (_spinCompleted && !_landedOnBorder)
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('ठीक है'),
          ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<String> names;
  _WheelPainter({required this.names});

  final List<Color> _colors = [
    Colors.teal,
    Colors.indigo,
    Colors.deepOrange,
    Colors.purple,
    Colors.green,
    Colors.amber.shade800,
    Colors.blue,
    Colors.pink,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * math.pi) / names.length;

    for (int i = 0; i < names.length; i++) {
      final paint = Paint()
        ..color = _colors[i % _colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweepAngle,
        sweepAngle,
        true,
        paint,
      );

      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweepAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * sweepAngle + sweepAngle / 2);

      final textPainter = TextPainter(
        text: TextSpan(
          text: names[i].length > 10 ? '${names[i].substring(0, 10)}..' : names[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(radius * 0.35, -textPainter.height / 2));
      canvas.restore();
    }

    canvas.drawCircle(center, 18, Paint()..color = Colors.white);
    canvas.drawCircle(center, 12, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =========================================================================
// 1. Login Screen
// =========================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mobile': _mobileController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(userData: data),
          ),
        );
      } else {
        _showMessage('लॉगिन विफल: मोबाइल नंबर या पासवर्ड जांचें');
      }
    } catch (e) {
      _showMessage('सर्वर से संपर्क नहीं हो पाया: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance_wallet, size: 80, color: Colors.teal),
                const SizedBox(height: 16),
                const Text(
                  'कमेटी एवं बचत समूह',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'मोबाइल नंबर',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'पासवर्ड',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('लॉगिन करें', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: const Text(
                    'नया सदस्य हैं? नया खाता बनाएं (Register)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 2. Register Screen
// =========================================================================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _nomineeNameController = TextEditingController();
  final TextEditingController _nomineePhoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    final fullName = _fullNameController.text.trim();
    final mobile = _mobileController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final upiId = _upiIdController.text.trim();
    final nomineeName = _nomineeNameController.text.trim();
    final nomineePhone = _nomineePhoneController.text.trim();

    if (fullName.isEmpty ||
        mobile.length < 10 ||
        email.isEmpty ||
        password.isEmpty ||
        upiId.isEmpty ||
        nomineeName.isEmpty ||
        nomineePhone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया सभी जानकारी (UPI ID और नॉमिनी सहित) सही से भरें')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': fullName,
          'mobile': mobile,
          'email': email,
          'password': password,
          'upi_id': upiId,
          'nominee_name': nomineeName,
          'nominee_phone': nomineePhone,
        }),
      );

      final data = jsonDecode(response.body);
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'खाता सफलतापूर्वक बन गया! अब लॉगिन करें।')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['detail']?.toString() ?? 'रजिस्ट्रेशन विफल रहा')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('त्रुटि: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('नया सदस्य पंजीकरण'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                const Icon(Icons.person_add, size: 60, color: Colors.teal),
                const SizedBox(height: 16),
                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'पूरा नाम (Full Name)',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'मोबाइल नंबर',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'ईमेल आईडी (Email)',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'पासवर्ड बनाएं',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _upiIdController,
                  decoration: const InputDecoration(
                    labelText: 'आपकी UPI ID (जैसे name@upi)',
                    prefixIcon: Icon(Icons.account_balance),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('नॉमिनी विवरण (सुरक्षा हेतु)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nomineeNameController,
                  decoration: const InputDecoration(
                    labelText: 'नॉमिनी का पूरा नाम',
                    prefixIcon: Icon(Icons.family_restroom),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nomineePhoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'नॉमिनी का मोबाइल नंबर',
                    prefixIcon: Icon(Icons.phone_in_talk),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('खाता बनाएं', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 3. Complete Dashboard Screen
// =========================================================================
class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const DashboardScreen({super.key, required this.userData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _myApprovedGroups = [];
  List<dynamic> _myJoinStatuses = [];
  List<dynamic> _adminPendingJoinRequests = [];
  List<dynamic> _adminPendingPayments = [];
  List<dynamic> _myNotifications = [];
  Map<String, dynamic>? _selectedGroupReport;
  int? _selectedGroupIdForReport;

  int? _selectedGroupIdForPayment;
  String _selectedPaymentMode = 'UPI';
  final TextEditingController _utrController = TextEditingController();
  final TextEditingController _cashDateController = TextEditingController(text: '2026-11-14');
  final TextEditingController _cashReceiverController = TextEditingController();

  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _receiverUpiController = TextEditingController();
  final TextEditingController _firstInstallmentDateController = TextEditingController(text: '2026-11-14');
  final TextEditingController _groupAmountController = TextEditingController(text: '2000');
  final TextEditingController _durationController = TextEditingController(text: '1');

  String _selectedFrequency = 'Weekly';
  String _selectedPenaltyType = 'ESCALATED_AFTER_2_DUE';
  final TextEditingController _penaltyValueController = TextEditingController(text: '5');
  final TextEditingController _penaltyAfter2DueController = TextEditingController(text: '10');

  String? _createdInviteCode;
  String? _createdGroupName;

  final TextEditingController _filterGroupCodeController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();

  String _selectedPayoutRequestType = 'SELF';
  int? _suggestedMemberUserId;
  int? _adminSelectedWinnerUserId;

  int? _selectedNewCoAdminUserId;
  int? _selectedChangeAdminTargetId;
  int? _selectedChangeAdminReplacementId;

  final TextEditingController _extraMonthsController = TextEditingController(text: '1');

  int get currentUserId => widget.userData['user_id'] ?? 1;
  bool get isAdminOfAnyGroup => _myApprovedGroups.any((g) => g['is_admin'] == true);
  int get unreadNotificationCount => _myNotifications.where((n) => n['is_read'] == false).length;

  int get previewTotalInstallments {
    final months = int.tryParse(_durationController.text.trim()) ?? 1;
    if (_selectedFrequency == 'Daily') return months * 30;
    if (_selectedFrequency == 'Weekly') return months * 4;
    if (_selectedFrequency == 'Quarterly') return ((months + 2) ~/ 3).clamp(1, 100);
    return months;
  }

  Map<String, dynamic>? get selectedPaymentGroup {
    if (_selectedGroupIdForPayment == null) return null;
    try {
      return _myApprovedGroups.firstWhere((g) => g['group_id'] == _selectedGroupIdForPayment);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshDashboardData();
  }

  Future<void> _refreshDashboardData() async {
    await _fetchMyGroups();
    await _fetchMyJoinStatuses();
    await _fetchAdminPendingRequests();
    await _fetchAdminPendingPayments();
    await _fetchMyNotifications();
    if (_selectedGroupIdForReport != null) {
      await _fetchGroupFullReport(_selectedGroupIdForReport!);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendWhatsAppMessage(String message, {String? phone}) async {
    final encodedMsg = Uri.encodeComponent(message);
    String url = 'https://wa.me/?text=$encodedMsg';
    if (phone != null && phone.trim().isNotEmpty) {
      String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length == 10) cleanPhone = '91$cleanPhone';
      url = 'https://wa.me/$cleanPhone?text=$encodedMsg';
    }
    final Uri waUri = Uri.parse(url);
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('WhatsApp खोलने में असमर्थ');
    }
  }

  Future<void> _exportGroupReportPdf(int groupId) async {
    final Uri pdfUri = Uri.parse('$baseUrl/report/group-pdf/$groupId');
    if (await canLaunchUrl(pdfUri)) {
      await launchUrl(pdfUri, mode: LaunchMode.externalApplication);
      _showSnack('ग्रुप की संपूर्ण PDF रिपोर्ट डाउनलोड हो रही है...');
    } else {
      _showSnack('PDF खोलने में समस्या आई');
    }
  }

  Future<void> _emailGroupReportToMembers(int groupId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/email-group-report/$groupId/$currentUserId'),
      );
      final resData = jsonDecode(response.body);
      _showSnack(resData['message'] ?? resData['detail'] ?? 'ईमेल भेजा गया');
    } catch (e) {
      _showSnack('त्रुटि: $e');
    }
  }

  void _shareGroupReportOnWhatsApp(Map<String, dynamic> report) {
    final int groupId = report['group_id'];
    final String pdfLink = '$baseUrl/report/group-pdf/$groupId';
    final List admins = report['admins'] ?? [];
    final List members = report['members'] ?? [];
    final List winnersHistory = report['winners_history'] ?? [];
    final List penaltyMembers = report['penalty_members'] ?? [];

    final StringBuffer sb = StringBuffer();
    sb.writeln('*${report['group_name']} (${report['group_code']}) - वित्तीय रिपोर्ट*');
    sb.writeln('• प्लान: ${report['frequency']} | ${report['duration_months']} माह (${report['total_plan_installments']} किस्तें)');
    if (admins.isNotEmpty) {
      final adminNames = admins.map((a) => '${a['full_name']} (${a['admin_role']})').join(', ');
      sb.writeln('• ग्रुप एडमिन: $adminNames');
    }
    sb.writeln('• कुल टारगेट (Target): ₹${report['total_target_amount']}');
    sb.writeln('• कुल अचीवमेंट (जमा): ₹${report['total_achievement']}');
    sb.writeln('• बकाया टारगेट: ₹${report['remaining_target']}');
    sb.writeln('• कुल पेनल्टी (Paid + Due): ₹${report['total_all_penalty']}');
    sb.writeln('• ग्रैंड टोटल (Target + Penalty): ₹${report['grand_total_with_penalty']}');

    if (winnersHistory.isNotEmpty) {
      sb.writeln('\n*🏆 लॉटरी विजेता रिपोर्ट (Winners):*');
      for (var w in winnersHistory) {
        sb.writeln('- साइकिल #${w['cycle_number']}: ${w['winner_name']} (${w['winner_mobile']}) — राशि ₹${w['pot_amount']}');
      }
    }

    sb.writeln('\n*सदस्य-वार विवरण:*');
    for (var m in members) {
      sb.writeln(
          '- ${m['full_name']}: जमा=${m['paid_installments']}/${m['total_plan_installments']} (₹${m['total_paid_amount']}), शेष=${m['remaining_installments']}, कुल पेनल्टी=₹${m['total_member_penalty']}');
    }
    if (penaltyMembers.isNotEmpty) {
      sb.writeln('\n*पेनल्टी विवरण:*');
      for (var pm in penaltyMembers) {
        sb.writeln('- ${pm['full_name']}: ₹${pm['total_member_penalty']} (${pm['penalty_reason']})');
      }
    }
    sb.writeln('\nPDF रिपोर्ट डाउनलोड लिंक: $pdfLink');

    _sendWhatsAppMessage(sb.toString());
  }

  Future<void> _fetchMyGroups() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/user/$currentUserId/groups'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _myApprovedGroups = data;
          if (_myApprovedGroups.isNotEmpty) {
            if (_selectedGroupIdForReport == null ||
                !_myApprovedGroups.any((g) => g['group_id'] == _selectedGroupIdForReport)) {
              _selectedGroupIdForReport = _myApprovedGroups.first['group_id'];
              _fetchGroupFullReport(_selectedGroupIdForReport!);
            }
            if (_selectedGroupIdForPayment != null &&
                !_myApprovedGroups.any((g) => g['group_id'] == _selectedGroupIdForPayment)) {
              _selectedGroupIdForPayment = null;
            }
          } else {
            _selectedGroupIdForReport = null;
            _selectedGroupReport = null;
            _selectedGroupIdForPayment = null;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMyJoinStatuses() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/user/$currentUserId/my-requests'));
      if (response.statusCode == 200) {
        setState(() {
          _myJoinStatuses = jsonDecode(response.body);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchAdminPendingRequests() async {
    try {
      final code = _filterGroupCodeController.text.trim();
      final uri = code.isEmpty
          ? Uri.parse('$baseUrl/admin/$currentUserId/pending-requests')
          : Uri.parse('$baseUrl/admin/$currentUserId/pending-requests?group_code=$code');

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        setState(() {
          _adminPendingJoinRequests = jsonDecode(response.body);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchAdminPendingPayments() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/$currentUserId/pending-payments'));
      if (response.statusCode == 200) {
        setState(() {
          _adminPendingPayments = jsonDecode(response.body);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMyNotifications() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/user/$currentUserId/notifications'));
      if (response.statusCode == 200) {
        setState(() {
          _myNotifications = jsonDecode(response.body);
        });
      }
    } catch (_) {}
  }

  void _openNotificationsDialog() async {
    await http.post(Uri.parse('$baseUrl/user/$currentUserId/notifications/read-all'));
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('आपकी नोटिफिकेशन अपडेट्स'),
        content: SizedBox(
          width: 420,
          height: 350,
          child: _myNotifications.isEmpty
              ? const Center(child: Text('अभी कोई नया नोटिफिकेशन नहीं है।'))
              : ListView.builder(
                  itemCount: _myNotifications.length,
                  itemBuilder: (_, i) {
                    final n = _myNotifications[i];
                    final bool isPayDue = n['action_type'] == 'PAYMENT_DUE' && n['group_id'] != null;
                    return Card(
                      color: n['is_read'] == false ? Colors.teal.shade50 : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('${n['message']}\n(${n['created_at']})'),
                            if (isPayDue) ...[
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _selectedGroupIdForPayment = n['group_id'];
                                  });
                                  _showSnack('पेमेंट सेक्शन में यह ग्रुप चुन लिया गया है!');
                                },
                                icon: const Icon(Icons.payment, size: 16),
                                label: const Text('सीधे भुगतान करें (Pay Now)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _fetchMyNotifications();
            },
            child: const Text('बंद करें'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchGroupFullReport(int groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/group/$groupId/full-report?user_id=$currentUserId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _selectedGroupIdForReport = groupId;
          _selectedGroupReport = data;
          _suggestedMemberUserId = null;
          _adminSelectedWinnerUserId = null;
          _selectedNewCoAdminUserId = null;
          _selectedChangeAdminTargetId = null;
          _selectedChangeAdminReplacementId = null;
          if (data['is_lottery_80_locked'] == true) {
            _selectedPayoutRequestType = 'LOTTERY';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    final receiverName = _receiverNameController.text.trim();
    final receiverUpi = _receiverUpiController.text.trim();
    final firstDate = _firstInstallmentDateController.text.trim();

    if (groupName.isEmpty || receiverName.isEmpty || receiverUpi.isEmpty || firstDate.isEmpty) {
      _showSnack('कृपया ग्रुप का नाम, रिसीवर नाम, UPI ID और पहली किस्त की तारीख भरें');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/create-group'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': currentUserId,
          'group_name': groupName,
          'receiver_name': receiverName,
          'receiver_upi_id': receiverUpi,
          'first_installment_date': firstDate,
          'frequency': _selectedFrequency,
          'duration_months': int.tryParse(_durationController.text.trim()) ?? 1,
          'amount_per_user': double.tryParse(_groupAmountController.text.trim()) ?? 2000,
          'penalty_type': _selectedPenaltyType,
          'penalty_value': double.tryParse(_penaltyValueController.text.trim()) ?? 0,
          'penalty_after_2_due_percent': double.tryParse(_penaltyAfter2DueController.text.trim()) ?? 0,
        }),
      );

      final resData = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _createdInviteCode = (resData['group_code'] ?? resData['invite_code'])?.toString();
          _createdGroupName = groupName;
        });
        _groupNameController.clear();
        _receiverNameController.clear();
        _receiverUpiController.clear();
        _showSnack(resData['message'] ?? 'ग्रुप बन गया!');
        _refreshDashboardData();
      } else {
        _showSnack(resData['detail']?.toString() ?? 'ग्रुप बनाने में त्रुटि');
      }
    } catch (e) {
      _showSnack('त्रुटि: $e');
    }
  }

  Future<void> _joinGroup() async {
    final code = _inviteCodeController.text.trim();
    if (code.isEmpty) {
      _showSnack('कृपया ग्रुप का Group Code दर्ज करें');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/join-group'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': currentUserId,
          'invite_code': code,
        }),
      );

      final resData = jsonDecode(response.body);
      _showSnack(resData['message'] ?? resData['detail']?.toString() ?? 'अनुरोध भेजा गया');
      if (response.statusCode == 200) {
        _inviteCodeController.clear();
        _refreshDashboardData();
      }
    } catch (e) {
      _showSnack('त्रुटि: $e');
    }
  }

  Future<void> _sendGovernanceRequest({
    required int groupId,
    required String actionType,
    required int targetUserId,
    int? newAdminUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/group/governance/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'group_id': groupId,
          'requested_by_admin_id': currentUserId,
          'action_type': actionType,
          'target_user_id': targetUserId,
          'new_admin_user_id': newAdminUserId,
        }),
      );
      final resData = jsonDecode(response.body);
      _showSnack(resData['message'] ?? resData['detail']?.toString() ?? 'अनुरोध भेजा गया');
      _refreshDashboardData();
    } catch (e) {
      _showSnack('त्रुटि: $e');
    }
  }

  Future<void> _respondGovernanceRequest(int requestId, String decision) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/group/governance/respond'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'request_id': requestId,
          'actor_user_id': currentUserId,
          'decision': decision,
        }),
      );
      final resData = jsonDecode(response.body);
      _showSnack(resData['message'] ?? resData['detail']?.toString() ?? 'अपडेट हो गया');
      _refreshDashboardData();
    } catch (e) {
      _showSnack('त्रुटि: $e');
    }
  }

  Future<void> _handleMemberApproval(int recordId, String action) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/approve-member'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': currentUserId,
          'member_record_id': recordId,
          'action': action,
        }),
      );

      final resData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _showSnack(resData['message'] ?? 'अपडेट हो गया');
        _refreshDashboardData();
        if (mounted && resData['whatsapp_message'] != null) {
          _showWhatsAppConfirmDialog(
            title: 'सदस्य अनुरोध $action हो गया!',
            userName: resData['user_name'] ?? '',
            userMobile: resData['user_mobile'] ?? '',
            message: resData['whatsapp_message'],
          );
        }
      } else {
        _showSnack(resData['detail']?.toString() ?? 'त्रुटि हुई');
      }
    } catch (e) {
      _showSnack('त्रुटि: $e');
    }
  }

  Future<void> _handlePaymentApproval(int transactionId, String action) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/approve-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': currentUserId,
          'transaction_id': transactionId,
          'action': action,
        }),
      );

      final resData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _showSnack(resData['message'] ?? 'पेमेंट अपडेट हो गया');
        _refreshDashboardData();
        if (mounted && resData['whatsapp_message'] != null) {
          _showWhatsAppConfirmDialog(
            title: 'पेमेंट $action हो गया!',
            userName: resData['user_name'] ?? '',
            userMobile: resData['user_mobile'] ?? '',
            message: resData['whatsapp_message'],
          );
        }
      } else {
        _showSnack(resData['detail']?.toString() ?? 'त्रुटि हुई');
      }
    } catch (e) {
      _showSnack('त्रुटि: $e');
    }
  }

  void _showWhatsAppConfirmDialog({
    required String title,
    required String userName,
    required String userMobile,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(
          'सदस्य ($userName) की ऐप आईडी में नोटिफिकेशन भेज दिया गया है।\n'
          'क्या आप उनके WhatsApp नंबर ($userMobile) पर भी यह संदेश भेजना चाहते हैं?\n\n'
          '"$message"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ठीक है'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _sendWhatsAppMessage(message, phone: userMobile);
            },
            icon: const Icon(Icons.send),
            label: const Text('WhatsApp पर भेजें'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _payDirectToGroupReceiver() async {
    final grp = selectedPaymentGroup;
    if (grp == null) {
      _showSnack('कृपया पहले ग्रुप चुनें');
      return;
    }
    final upiId = grp['receiver_upi_id'];
    final receiverName = Uri.encodeComponent(grp['receiver_name'] ?? 'CommitteeReceiver');
    final totalPayable = grp['user_total_payable_now'] ?? grp['amount_per_user'];
    final note = Uri.encodeComponent('${grp['group_name']} Cycle ${grp['active_cycle_number'] ?? 1}');

    final Uri upiUri = Uri.parse(
      'upi://pay?pa=$upiId&pn=$receiverName&am=$totalPayable&cu=INR&tn=$note',
    );

    if (await canLaunchUrl(upiUri)) {
      await launchUrl(upiUri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('इस डिवाइस पर कोई UPI ऐप नहीं मिला (Receiver UPI: $upiId | देय राशि: ₹$totalPayable)');
    }
  }

  Future<void> _submitUtrForSelectedGroup() async {
    final grp = selectedPaymentGroup;
    if (grp == null) {
      _showSnack('कृपया पहले ग्रुप चुनें');
      return;
    }
    final utr = _utrController.text.trim();
    if (utr.length < 12) {
      _showSnack('कृपया सही 12-अंकों का UTR नंबर दर्ज करें');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payment/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'group_id': grp['group_id'],
          'payer_user_id': currentUserId,
          'utr_number': utr,
          'payment_app': 'UPI',
        }),
      );

      final resData = jsonDecode(response.body);
      _showSnack(resData['message'] ?? resData['detail'] ?? 'UTR सबमिट हो गया');
      if (response.statusCode == 200) {
        _utrController.clear();
        _refreshDashboardData();
      }
    } catch (e) {
      _showSnack('त्रुटि: $e');
    }
  }

  Future<void> _submitCashForSelectedGroup() async {
    final grp = selectedPaymentGroup;
    if (grp == null) {
      _showSnack('कृपया पहले ग्रुप चुनें');
      return;
    }
    final receiver = _cashReceiverController.text.trim();
    final date = _cashDateController.text.trim();
    if (receiver.isEmpty || date.isEmpty) {
      _showSnack('कृपया कैश प्राप्त करने की तारीख और प्राप्तकर्ता का नाम भरें');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payment/submit-cash'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'group_id': grp['group_id'],
          'payer_user_id': currentUserId,
          'payment_app': 'CASH',
          'cash_received_date': date,
          'cash_receiver_name': receiver,
        }),
      );

      final resData = jsonDecode(response.body);
      _showSnack(resData['message'] ?? resData['detail']?.toString() ?? 'कैश एंट्री भेजी गई');
      if (response.statusCode == 200) {
        _cashReceiverController.clear();
        _refreshDashboardData();
      }
    } catch (e) {
      _showSnack('त्रुटि: $e');
    }
  }

  Future<void> _requestOrApproveLotteryPermission(int cycleId, List<dynamic> members) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cycle/lottery-permission'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cycle_id': cycleId,
          'admin_id': currentUserId,
        }),
      );
      final resData = jsonDecode(response.body);
      _showSnack(resData['message'] ?? resData['detail']?.toString() ?? 'अपडेट हुआ');
      if (response.statusCode == 200 && resData['ready_to_spin'] == true && mounted) {
        await _spinWheelAndSaveExactWinner(members);
      } else {
        _refreshDashboardData();
      }
    } catch (e) {
      _showSnack('त्रुटि: $e');
    }
  }

  Future<void> _spinWheelAndSaveExactWinner(List<dynamic> members) async {
    if (_selectedGroupReport == null || _selectedGroupReport!['latest_cycle_id'] == null) return;
    final int cycleId = _selectedGroupReport!['latest_cycle_id'];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LotterySpinWheelDialog(
        members: members,
        onWinnerSelected: (winnerMember) async {
          final int exactWinnerUserId = winnerMember['user_id'];
          await http.post(
            Uri.parse('$baseUrl/admin/finalize-payout'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'admin_id': currentUserId,
              'cycle_id': cycleId,
              'mode': 'DIRECT',
              'winner_user_id': exactWinnerUserId,
            }),
          );
        },
      ),
    );
    _refreshDashboardData();
  }

  Future<void> _submitPayoutRequest() async {
    if (_selectedGroupReport == null || _selectedGroupReport!['latest_cycle_id'] == null) return;
    if (_selectedPayoutRequestType == 'SUGGEST_MEMBER' && _suggestedMemberUserId == null) {
      _showSnack('कृपया सुझाव के लिए किसी सदस्य को चुनें');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cycle/payout-request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cycle_id': _selectedGroupReport!['latest_cycle_id'],
          'user_id': currentUserId,
          'request_type': _selectedPayoutRequestType,
          'suggested_user_id': _suggestedMemberUserId,
        }),
      );
      final resData = jsonDecode(response.body);
      _showSnack(resData['message'] ?? resData['detail']?.toString() ?? 'अनुरोध भेजा गया');
      _refreshDashboardData();
    } catch (e) {
      _showSnack('त्रुटि: $e');
    }
  }

  Future<void> _adminFinalizePayoutDirect() async {
    if (_selectedGroupReport == null || _selectedGroupReport!['latest_cycle_id'] == null) return;
    if (_adminSelectedWinnerUserId == null) {
      _showSnack('कृपया विजेता सदस्य चुनें');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/finalize-payout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': currentUserId,
          'cycle_id': _selectedGroupReport!['latest_cycle_id'],
          'mode': 'DIRECT',
          'winner_user_id': _adminSelectedWinnerUserId,
        }),
      );
      final resData = jsonDecode(response.body);
      _showSnack(resData['message'] ?? resData['detail'] ?? 'भुगतान वितरण पूरा हुआ');
      _refreshDashboardData();
    } catch (e) {
      _showSnack('त्रुटि: $e');
    }
  }

  Future<void> _adminNextCycleOrExtend(String action) async {
    if (_selectedGroupReport == null) return;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/group-next-action'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': currentUserId,
          'group_id': _selectedGroupReport!['group_id'],
          'action': action,
          'extra_months': int.tryParse(_extraMonthsController.text.trim()) ?? 1,
        }),
      );
      final resData = jsonDecode(response.body);
      _showSnack(resData['message'] ?? resData['detail'] ?? 'अपडेट हो गया');
      _refreshDashboardData();
    } catch (e) {
      _showSnack('त्रुटि: $e');
    }
  }

  Future<void> _adminDeleteGroupWithEmailAudit(int groupId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/delete-group/$groupId/$currentUserId'),
      );
      final resData = jsonDecode(response.body);
      _showSnack(resData['message'] ?? resData['detail'] ?? 'प्रक्रिया पूरी हुई');
      _refreshDashboardData();
    } catch (e) {
      _showSnack('त्रुटि: $e');
    }
  }

  // चुने हुए ग्रुप के ठीक नीचे खुलने वाला Complete Report + Admin Info + Winners History
  Widget _buildInlineGroupReportPanel(Map<String, dynamic> report) {
    final int groupId = report['group_id'];
    final bool isAdmin = report['is_admin'] == true;
    final int adminCount = report['admin_count'] ?? 1;
    final List admins = report['admins'] ?? [];
    final List members = report['members'] ?? [];
    final List winnersHistory = report['winners_history'] ?? [];
    final List govRequests = report['governance_requests'] ?? [];
    final List penaltyMembers = report['penalty_members'] ?? [];

    final bool isPayoutEligible = report['is_payout_eligible'] == true;
    final bool payoutDone = report['latest_cycle_payout_completed'] == true;
    final bool isLottery80Locked = report['is_lottery_80_locked'] == true;
    final bool isLotterySpinApproved = report['is_lottery_spin_approved_by_admins'] == true;
    final int? lotteryReqByAdmin = report['lottery_requested_by_admin_id'];

    final List nonAdminMembers = members.where((m) => m['is_group_admin'] != true).toList();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'संपूर्ण रिपोर्ट (${report['frequency']} | ${report['duration_months']} माह = ${report['total_plan_installments']} किस्तें)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
              ),
              IconButton(
                tooltip: 'रिपोर्ट बंद करें',
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _selectedGroupIdForReport = null;
                    _selectedGroupReport = null;
                  });
                },
              ),
            ],
          ),
          const Divider(),

          // PDF / WhatsApp / Email बटन
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _exportGroupReportPdf(groupId),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Export to PDF (डाउनलोड)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _shareGroupReportOnWhatsApp(report),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('WhatsApp पर भेजें'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
              if (isAdmin)
                ElevatedButton.icon(
                  onPressed: () => _emailGroupReportToMembers(groupId),
                  icon: const Icon(Icons.email, size: 18),
                  label: const Text('सभी सदस्यों को E-mail करें'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ग्रुप के एडमिन की जानकारी (सभी सदस्यों को रिपोर्ट कार्ड में दिखेगी)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🛡️ ग्रुप एडमिन विवरण (Group Admins - $adminCount/2):',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                ),
                const SizedBox(height: 4),
                ...admins.map((a) => Text(
                      '• ${a['full_name']} (${a['mobile']}) — [${a['admin_role']}] | UPI: ${a['upi_id'] ?? '-'}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 5 वित्तीय कार्ड्स
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMetricBox(
                'कुल टारगेट (${report['total_plan_installments']} किस्त)',
                '₹${report['total_target_amount']}',
                Colors.indigo,
              ),
              _buildMetricBox(
                'कुल अचीवमेंट (जमा)',
                '₹${report['total_achievement']}',
                Colors.green.shade800,
              ),
              _buildMetricBox(
                'बकाया टारगेट',
                '₹${report['remaining_target']}',
                Colors.orange.shade900,
              ),
              _buildMetricBox(
                'कुल पेनल्टी (Paid+Due)',
                '₹${report['total_all_penalty'] ?? report['total_due_penalty']}',
                Colors.red.shade800,
              ),
              _buildMetricBox(
                'ग्रैंड टोटल (Target+Pen)',
                '₹${report['grand_total_with_penalty'] ?? report['total_target_amount']}',
                Colors.purple.shade800,
              ),
            ],
          ),

          // 🏆 विजेताओं की रिपोर्ट (100% अचीवमेंट और लॉटरी निकलने के बाद सभी विजेताओं का रिकॉर्ड)
          if (winnersHistory.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade600, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏆 लॉटरी एवं साइकिल विजेता रिपोर्ट (Winners Report):',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  ...winnersHistory.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• साइकिल #${w['cycle_number']} विजेता: ${w['winner_name']} (${w['winner_mobile']}) | '
                          'UPI: ${w['winner_upi_id']} | कुल पोट राशि: ₹${w['pot_amount']}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade900,
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ],

          if (penaltyMembers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ पेनल्टी विवरण (जिन सदस्यों को पेनल्टी लगी है):',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900),
                  ),
                  const SizedBox(height: 4),
                  ...penaltyMembers.map((pm) => Text(
                        '• ${pm['full_name']} (${pm['mobile']}): कुल पेनल्टी ₹${pm['total_member_penalty']} '
                        '(जमा: ₹${pm['paid_penalty']}, बकाया: ₹${pm['due_penalty']}) — ${pm['penalty_reason']}',
                        style: const TextStyle(fontSize: 13),
                      )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          if (payoutDone && report['latest_cycle_winner_name'] != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade700, width: 1.5),
              ),
              child: Text(
                '✅ वर्तमान साइकिल #${report['latest_cycle_number']} का वितरण पूर्ण — विजेता: ${report['latest_cycle_winner_name']}',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900, fontSize: 15),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // POT CLAIM / 80% LOCK / DUAL-ADMIN SPIN LOTTERY
          if (isPayoutEligible) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎉 100% साइकिल अचीवमेंट पूर्ण! साइकिल #${report['latest_cycle_number']} राशि वितरण:',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 15),
                  ),
                  Text(
                    'लॉटरी वोट: ${report['lottery_vote_count']}/${report['total_members']} '
                    '${isLottery80Locked ? "(80% वोट पूर्ण — अन्य विकल्प लॉक, केवल Admin Lottery सक्रिय)" : "(80% होने पर अन्य सुझाव स्वतः बंद हो जाएंगे)"}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  if (!isLottery80Locked) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedPayoutRequestType,
                      decoration: const InputDecoration(
                        labelText: 'अपना विकल्प चुनें',
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'SELF', child: Text('मैं स्वयं यह राशि लेना चाहता हूँ (Self Request)')),
                        DropdownMenuItem(value: 'SUGGEST_MEMBER', child: Text('किसी अन्य सदस्य का नाम सुझाएं')),
                        DropdownMenuItem(value: 'LOTTERY', child: Text('लॉटरी (Spin Wheel Lottery) का सुझाव दें')),
                      ],
                      onChanged: (val) => setState(() => _selectedPayoutRequestType = val!),
                    ),
                    if (_selectedPayoutRequestType == 'SUGGEST_MEMBER') ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _suggestedMemberUserId,
                        decoration: const InputDecoration(
                          labelText: 'सदस्य का नाम चुनें',
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(),
                        ),
                        items: members
                            .map((m) => DropdownMenuItem<int>(
                                  value: m['user_id'],
                                  child: Text('${m['full_name']} (${m['mobile']})'),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _suggestedMemberUserId = val),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _submitPayoutRequest,
                      icon: const Icon(Icons.how_to_vote),
                      label: const Text('अपना अनुरोध / सुझाव भेजें'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.deepOrange),
                      ),
                      child: const Text(
                        '🔒 80% या अधिक सदस्यों ने लॉटरी का अनुरोध किया है, इसलिए अन्य सभी सुझाव विकल्प बंद कर दिए गए हैं। अब केवल ग्रुप एडमिन द्वारा Spin Lottery निकाली जाएगी।',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                    ),
                  ],

                  if ((report['payout_requests'] as List).isNotEmpty) ...[
                    const Divider(),
                    const Text('सदस्यों के प्राप्त अनुरोध / सुझाव:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ...(report['payout_requests'] as List).map((r) => Text(
                          '• ${r['by_user']}: ${r['request_type']} ${r['suggested_member'] != null ? "(सुझाव: ${r['suggested_member']})" : ""}',
                        )),
                  ],

                  if (isAdmin) ...[
                    const Divider(),
                    const Text('एडमिन लॉटरी नियंत्रण (Dual-Admin Approval & Spin Wheel):',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    const SizedBox(height: 8),

                    if (!isLottery80Locked) ...[
                      DropdownButtonFormField<int>(
                        value: _adminSelectedWinnerUserId,
                        decoration: const InputDecoration(
                          labelText: 'सीधा विजेता सदस्य चुनें (80% लॉटरी लॉक न होने पर)',
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(),
                        ),
                        items: members
                            .map((m) => DropdownMenuItem<int>(
                                  value: m['user_id'],
                                  child: Text(
                                      '${m['full_name']} ${m['has_received_pot'] == true ? "(पहले मिल चुका)" : ""}'),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _adminSelectedWinnerUserId = val),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _adminFinalizePayoutDirect,
                        icon: const Icon(Icons.check),
                        label: const Text('चुने गए सदस्य को आवंटित करें'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (isLotterySpinApproved)
                      ElevatedButton.icon(
                        onPressed: () => _spinWheelAndSaveExactWinner(members),
                        icon: const Icon(Icons.casino),
                        label: const Text('🎡 दोनों एडमिन से स्वीकृत: Spin Wheel घुमाएं'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else if (lotteryReqByAdmin == null)
                      ElevatedButton.icon(
                        onPressed: () =>
                            _requestOrApproveLotteryPermission(report['latest_cycle_id'], members),
                        icon: const Icon(Icons.send),
                        label: Text(adminCount > 1
                            ? 'लॉटरी निकालने का अनुरोध भेजें (2nd Admin Approval हेतु)'
                            : 'लॉटरी Spin Wheel सक्रिय करें'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else if (lotteryReqByAdmin != currentUserId)
                      ElevatedButton.icon(
                        onPressed: () =>
                            _requestOrApproveLotteryPermission(report['latest_cycle_id'], members),
                        icon: const Icon(Icons.verified),
                        label: const Text('✅ दूसरे एडमिन का लॉटरी अनुरोध Approve करें व Spin चलाएं'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else
                      const Text(
                        '⏳ आपने लॉटरी निकालने का अनुरोध भेज दिया है। दूसरे एडमिन के Approve करते ही Spin Wheel खुल जाएगा।',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // DUAL-ADMIN & MEMBER GOVERNANCE PANEL
          if (isAdmin) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ग्रुप एडमिन प्रबंधन (वर्तमान एडमिन: $adminCount/2 — न्यूनतम 1, अधिकतम 2):',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  ...admins.map((adm) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('• ${adm['full_name']} (${adm['mobile']}) — [${adm['admin_role']}]',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (adminCount > 1)
                            TextButton.icon(
                              onPressed: () => _sendGovernanceRequest(
                                groupId: groupId,
                                actionType: 'REMOVE_ADMIN',
                                targetUserId: adm['user_id'],
                              ),
                              icon: const Icon(Icons.person_remove, size: 16, color: Colors.red),
                              label: const Text('Admin हटाएं', style: TextStyle(color: Colors.red)),
                            ),
                        ],
                      )),
                  const Divider(),

                  if (adminCount < 2 && nonAdminMembers.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedNewCoAdminUserId,
                            decoration: const InputDecoration(
                              labelText: 'दूसरा Co-Admin चुनें (अधिकतम 2)',
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(),
                            ),
                            items: nonAdminMembers
                                .map((m) => DropdownMenuItem<int>(
                                      value: m['user_id'],
                                      child: Text('${m['full_name']} (${m['mobile']})'),
                                    ))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedNewCoAdminUserId = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _selectedNewCoAdminUserId == null
                              ? null
                              : () => _sendGovernanceRequest(
                                    groupId: groupId,
                                    actionType: 'ADD_CO_ADMIN',
                                    targetUserId: _selectedNewCoAdminUserId!,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Co-Admin बनाएं'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (nonAdminMembers.isNotEmpty) ...[
                    const Text('एडमिन बदलें (Change Admin — स्वयं व दोनों एडमिन की मंज़ूरी अनिवार्य):',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedChangeAdminTargetId,
                            decoration: const InputDecoration(
                              labelText: 'हटने वाला Admin',
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(),
                            ),
                            items: admins
                                .map((a) => DropdownMenuItem<int>(
                                      value: a['user_id'],
                                      child: Text(a['full_name']),
                                    ))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedChangeAdminTargetId = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedChangeAdminReplacementId,
                            decoration: const InputDecoration(
                              labelText: 'नया Admin सदस्य',
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(),
                            ),
                            items: nonAdminMembers
                                .map((m) => DropdownMenuItem<int>(
                                      value: m['user_id'],
                                      child: Text(m['full_name']),
                                    ))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedChangeAdminReplacementId = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ElevatedButton.icon(
                      onPressed: (_selectedChangeAdminTargetId == null ||
                              _selectedChangeAdminReplacementId == null)
                          ? null
                          : () => _sendGovernanceRequest(
                                groupId: groupId,
                                actionType: 'CHANGE_ADMIN',
                                targetUserId: _selectedChangeAdminTargetId!,
                                newAdminUserId: _selectedChangeAdminReplacementId!,
                              ),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Admin बदलने का अनुरोध भेजें'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade800,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (govRequests.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📋 Admin व Member बदलाव अनुरोध एवं ऑडिट रिपोर्ट:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 15)),
                    const SizedBox(height: 6),
                    ...govRequests.map((gr) {
                      final bool isPending = gr['status'] == 'Pending';
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• कार्य: ${gr['action_type']} | लक्ष्य: ${gr['target_user_name']} '
                                '${gr['new_admin_name'] != null ? "-> नया Admin: ${gr['new_admin_name']}" : ""} [${gr['status']}]',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'अनुरोधकर्ता: ${gr['requested_by_name']} | Admin1: ${gr['admin1_approved'] ? "✅" : "⏳"} | '
                                'Admin2: ${gr['admin2_approved'] ? "✅" : "⏳"} '
                                '${(gr['action_type'] == 'REMOVE_ADMIN' || gr['action_type'] == 'CHANGE_ADMIN') ? "| स्वयं की मंज़ूरी: ${gr['target_self_approved'] ? "✅" : "⏳"}" : ""}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (isPending && gr['can_user_respond'] == true) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _respondGovernanceRequest(gr['request_id'], 'Approved'),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Approve करें'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _respondGovernanceRequest(gr['request_id'], 'Rejected'),
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Reject करें'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade700),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('एडमिन: अगली साइकिल, अवधि विस्तार या ग्रुप समाप्ति (80% Email नियम):',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _adminNextCycleOrExtend('START_NEXT_CYCLE'),
                        icon: const Icon(Icons.skip_next, size: 18),
                        label: const Text('अगली साइकिल शुरू करें'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _adminNextCycleOrExtend('EXTEND_GROUP'),
                        icon: const Icon(Icons.update, size: 18),
                        label: const Text('अवधि बढ़ाएं (Email ऑडिट)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _adminDeleteGroupWithEmailAudit(groupId),
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text('E-mail कर डिलीट करें'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // इसी ग्रुप के सदस्य एवं प्रबंधन
          const Text('इसी ग्रुप के सदस्य एवं प्रबंधन (Member Management):',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...members.map((m) {
            final bool hasPenalty = (m['total_member_penalty'] ?? 0) > 0;
            final bool isMemberAdmin = m['is_group_admin'] == true;
            return Card(
              color: Colors.grey.shade50,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: hasPenalty ? Colors.red.shade100 : Colors.green.shade100,
                  child: Text('${m['user_id']}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasPenalty ? Colors.red : Colors.green)),
                ),
                title: Text(
                  '${m['full_name']} (${m['mobile']}) [${m['admin_role']}] ${m['has_received_pot'] == true ? "🏆" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'जमा किस्तें: ${m['paid_installments']}/${m['total_plan_installments']} (₹${m['total_paid_amount']}) | '
                  'शेष किस्तें: ${m['remaining_installments']}\n'
                  'कुल पेनल्टी: ₹${m['total_member_penalty']} (जमा: ₹${m['paid_penalty']} | बकाया: ₹${m['due_penalty']})',
                  style: TextStyle(
                    color: hasPenalty ? Colors.red.shade900 : Colors.black87,
                    fontWeight: hasPenalty ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: (isAdmin && !isMemberAdmin)
                    ? IconButton(
                        tooltip: 'सदस्य को हटाने का अनुरोध भेजें (दोनों Admin की मंज़ूरी से)',
                        icon: const Icon(Icons.person_remove_alt_1, color: Colors.red),
                        onPressed: () => _sendGovernanceRequest(
                          groupId: groupId,
                          actionType: 'REMOVE_MEMBER',
                          targetUserId: m['user_id'],
                        ),
                      )
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String userName = widget.userData['full_name'] ?? widget.userData['name'] ?? 'सदस्य';
    return Scaffold(
      appBar: AppBar(
        title: Text('स्वागत है, $userName (ID: $currentUserId)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'नोटिफिकेशन देखें',
                icon: const Icon(Icons.notifications),
                onPressed: _openNotificationsDialog,
              ),
              if (unreadNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      '$unreadNotificationCount',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'डेटा रीफ्रेश करें',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDashboardData,
          ),
          IconButton(
            tooltip: 'लॉगआउट',
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_myJoinStatuses.isNotEmpty)
              Card(
                elevation: 2,
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('आपके ग्रुप सदस्यता अनुरोधों की स्थिति:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _myJoinStatuses.map((req) {
                          final status = req['status'];
                          Color chipColor = status == 'Approved'
                              ? Colors.green.shade100
                              : (status == 'Rejected' ? Colors.red.shade100 : Colors.amber.shade200);
                          return Chip(
                            backgroundColor: chipColor,
                            label: Text(
                              '${req['group_name']} (${req['group_code']}): $status',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // SECTION 1: किस्त भुगतान
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. किस्त भुगतान करें (Group चुनें -> Auto-Cycle & Penalty सहित UPI / Cash)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _selectedGroupIdForPayment,
                      decoration: const InputDecoration(
                        labelText: 'भुगतान करने के लिए कमेटी ग्रुप चुनें (Select Group)',
                        prefixIcon: Icon(Icons.groups),
                        border: OutlineInputBorder(),
                      ),
                      items: _myApprovedGroups
                          .map((g) => DropdownMenuItem<int>(
                                value: g['group_id'],
                                child: Text(
                                  g['is_user_target_completed'] == true
                                      ? '${g['group_name']} (सभी ${g['total_installments']} किस्तें पूर्ण ✅)'
                                      : '${g['group_name']} (${g['frequency']}) - देय: ₹${g['user_total_payable_now']}',
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedGroupIdForPayment = val;
                        });
                      },
                    ),
                    if (selectedPaymentGroup != null) ...[
                      const SizedBox(height: 12),
                      if (selectedPaymentGroup!['is_user_target_completed'] == true)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade700),
                          ),
                          child: Text(
                            '🎉 बधाई हो! इस ग्रुप में आपकी सभी ${selectedPaymentGroup!['total_installments']}/${selectedPaymentGroup!['total_installments']} किस्तें जमा/सबमिट हो चुकी हैं। अब इस ग्रुप में कोई भुगतान शेष नहीं है।',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.green.shade900,
                            ),
                          ),
                        )
                      else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (selectedPaymentGroup!['user_due_penalty_now'] ?? 0) > 0
                                ? Colors.red.shade50
                                : Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (selectedPaymentGroup!['user_due_penalty_now'] ?? 0) > 0
                                  ? Colors.red.shade300
                                  : Colors.indigo.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'अधिकृत पेमेंट रिसीवर: ${selectedPaymentGroup!['receiver_name']} (${selectedPaymentGroup!['receiver_upi_id']})',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'आपकी प्रगति: ${selectedPaymentGroup!['user_approved_installments']}/${selectedPaymentGroup!['total_installments']} स्वीकृत | '
                                'अभी देय साइकिल: #${(selectedPaymentGroup!['user_cycles_to_pay_numbers'] as List?)?.join(", #") ?? "-"}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'मूल किस्त (${selectedPaymentGroup!['user_installments_to_pay_now']} किस्त): ₹${selectedPaymentGroup!['user_principal_payable_now']} + बकाया पेनल्टी: ₹${selectedPaymentGroup!['user_due_penalty_now']} = कुल देय: ₹${selectedPaymentGroup!['user_total_payable_now']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text('पेनल्टी स्थिति: ${selectedPaymentGroup!['user_penalty_reason']}'),
                              Text(
                                'अंतिम तिथि (Due Date): ${selectedPaymentGroup!['active_cycle_due_date'] ?? '-'}',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'UPI',
                              label: Text('Online UPI Payment'),
                              icon: Icon(Icons.qr_code),
                            ),
                            ButtonSegment(
                              value: 'CASH',
                              label: Text('Cash Payment (नकद)'),
                              icon: Icon(Icons.money),
                            ),
                          ],
                          selected: {_selectedPaymentMode},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _selectedPaymentMode = newSelection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        if (_selectedPaymentMode == 'UPI') ...[
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _payDirectToGroupReceiver,
                              icon: const Icon(Icons.send_to_mobile),
                              label: Text(
                                'सीधे ${selectedPaymentGroup!['receiver_name']} को कुल ₹${selectedPaymentGroup!['user_total_payable_now']} भेजें',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const Divider(height: 24),
                          TextField(
                            controller: _utrController,
                            keyboardType: TextInputType.number,
                            maxLength: 12,
                            decoration: const InputDecoration(
                              labelText: 'भुगतान के बाद 12-अंकों का UTR नंबर दर्ज करें',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: _submitUtrForSelectedGroup,
                              icon: const Icon(Icons.verified),
                              label: const Text('UTR सत्यापन हेतु सबमिट करें (Admin Approval)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ] else ...[
                          TextField(
                            controller: _cashDateController,
                            decoration: const InputDecoration(
                              labelText: 'कैश प्राप्त करने की तारीख (YYYY-MM-DD)',
                              prefixIcon: Icon(Icons.calendar_today),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _cashReceiverController,
                            decoration: const InputDecoration(
                              labelText: 'कैश प्राप्तकर्ता का नाम (Cash Receiver Name)',
                              prefixIcon: Icon(Icons.person_pin),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _submitCashForSelectedGroup,
                              icon: const Icon(Icons.request_quote),
                              label: Text(
                                'कैश एंट्री (कुल ₹${selectedPaymentGroup!['user_total_payable_now']}) सबमिट करें',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade800,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'भुगतान करने के लिए ऊपर ड्रॉपडाउन से अपना ग्रुप चुनें।',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SECTION 2: मेरे स्वीकृत कमेटी ग्रुप्स एवं Inline रिपोर्ट कार्ड
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('2. मेरे स्वीकृत कमेटी ग्रुप्स एवं रिपोर्ट कार्ड (${_myApprovedGroups.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const Divider(),
                    if (_myApprovedGroups.isEmpty)
                      const Text('अभी आप किसी भी स्वीकृत ग्रुप में नहीं हैं।')
                    else
                      ..._myApprovedGroups.map((g) {
                        final bool isSelected = g['group_id'] == _selectedGroupIdForReport;
                        final bool isAdmin = g['is_admin'] == true;
                        final List adminsInfo = g['admins_info'] ?? [];
                        final String adminsText = adminsInfo
                            .map((a) => '${a['full_name']} (${a['role']})')
                            .join(', ');

                        final String inviteText =
                            'नमस्ते! हमारी कमेटी "${g['group_name']}" में जुड़ने के लिए ऐप में यह Invite Code दर्ज करें:\n'
                            'Group Code: *${g['group_code']}*\n'
                            'प्लान: ${g['frequency']} | ${g['duration_months']} माह (${g['total_installments']} किस्तें) | किस्त: ₹${g['amount_per_user']}';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.teal.shade50 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? Colors.teal : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${g['group_name']} (Code: ${g['group_code']})',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(isAdmin ? 'Admin' : 'Member',
                                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      backgroundColor: isAdmin ? Colors.indigo : Colors.teal,
                                    ),
                                  ],
                                ),
                                Text(
                                  'प्लान: ${g['frequency']} | अवधि: ${g['duration_months']} माह = कुल ${g['total_installments']} किस्तें | किस्त: ₹${g['amount_per_user']}\n'
                                  'रिसीवर: ${g['receiver_name']} (${g['receiver_upi_id']}) | कुल सदस्य: ${g['approved_members']}\n'
                                  'ग्रुप एडमिन: $adminsText',
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (isSelected) {
                                          setState(() {
                                            _selectedGroupIdForReport = null;
                                            _selectedGroupReport = null;
                                          });
                                        } else {
                                          _fetchGroupFullReport(g['group_id']);
                                        }
                                      },
                                      icon: Icon(isSelected ? Icons.expand_less : Icons.bar_chart, size: 18),
                                      label: Text(isSelected ? 'रिपोर्ट व प्रबंधन छुपाएं' : 'रिपोर्ट, विजेता व Admin प्रबंधन'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isSelected ? Colors.teal : Colors.indigo,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _exportGroupReportPdf(g['group_id']),
                                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                                      label: const Text('PDF Export'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    if (isAdmin)
                                      ElevatedButton.icon(
                                        onPressed: () => _sendWhatsAppMessage(inviteText),
                                        icon: const Icon(Icons.share, size: 18),
                                        label: const Text('WhatsApp कोड भेजें'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade700,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),

                                if (isSelected && _selectedGroupReport != null)
                                  _buildInlineGroupReportPanel(_selectedGroupReport!),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SECTION 3: एडमिन पैनल - पेंडिंग पेमेंट अप्रूवल
            if (isAdminOfAnyGroup || _adminPendingPayments.isNotEmpty) ...[
              Card(
                elevation: 3,
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('3. एडमिन पैनल: पेंडिंग पेमेंट अप्रूवल - UPI व Cash (${_adminPendingPayments.length})',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                      const Text('नोट: 2 दिन के भीतर निर्णय न लेने पर पेमेंट स्वतः स्वीकृत (Auto-Approved) हो जाएगा।',
                          style: TextStyle(fontSize: 12, color: Colors.black54)),
                      const Divider(),
                      if (_adminPendingPayments.isEmpty)
                        const Text('आपके ग्रुप्स में अभी कोई पेमेंट अप्रूवल के लिए पेंडिंग नहीं है।')
                      else
                        ..._adminPendingPayments.map((p) {
                          final bool isCash = p['payment_mode'] == 'CASH';
                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'सदस्य: ${p['full_name']} | किस्त: ₹${p['amount_paid']} + पेनल्टी: ₹${p['penalty_paid']}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                      ),
                                      Chip(
                                        label: Text(p['payment_mode'],
                                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                                        backgroundColor: isCash ? Colors.orange.shade800 : Colors.blue.shade800,
                                      ),
                                    ],
                                  ),
                                  Text(
                                    isCash
                                        ? 'ग्रुप: ${p['group_name']} (साइकिल #${p['cycle_number']}) | Ref: ${p['utr_or_ref']}\n'
                                            'कैश तारीख: ${p['cash_received_date']} | प्राप्तकर्ता: ${p['cash_receiver_name']}'
                                        : 'ग्रुप: ${p['group_name']} (साइकिल #${p['cycle_number']})\n'
                                            'UPI UTR नंबर: ${p['utr_or_ref']}',
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _handlePaymentApproval(p['transaction_id'], 'Approved'),
                                        icon: const Icon(Icons.check_circle, size: 18),
                                        label: const Text('Approve व रसीद भेजें'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade700,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _handlePaymentApproval(p['transaction_id'], 'Rejected'),
                                        icon: const Icon(Icons.cancel, size: 18),
                                        label: const Text('Reject'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade700,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // SECTION 4: एडमिन पैनल - पेंडिंग जॉइन रिक्वेस्ट
            if (isAdminOfAnyGroup || _adminPendingJoinRequests.isNotEmpty) ...[
              Card(
                elevation: 3,
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('4. एडमिन पैनल: पेंडिंग जॉइन रिक्वेस्ट (Group Code अनुसार)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _filterGroupCodeController,
                              decoration: const InputDecoration(
                                labelText: 'Group Code से फ़िल्टर करें',
                                fillColor: Colors.white,
                                filled: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: _fetchAdminPendingRequests,
                            icon: const Icon(Icons.search),
                            label: const Text('खोजें'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_adminPendingJoinRequests.isEmpty)
                        const Text('कोई पेंडिंग जॉइन रिक्वेस्ट नहीं है।')
                      else
                        ..._adminPendingJoinRequests.map((req) => Card(
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'सदस्य: ${req['full_name']} (Mobile: ${req['mobile']})',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text('ग्रुप: ${req['group_name']} | Group Code: ${req['group_code']}'),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _handleMemberApproval(req['member_record_id'], 'Approved'),
                                          icon: const Icon(Icons.check, size: 18),
                                          label: const Text('Approve करें'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _handleMemberApproval(req['member_record_id'], 'Rejected'),
                                          icon: const Icon(Icons.close, size: 18),
                                          label: const Text('Reject करें'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // SECTION 5: नया कमेटी ग्रुप बनाएं
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('5. नया कमेटी ग्रुप बनाएं (Smart Frequency & Penalty Rules)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _groupNameController,
                      decoration: const InputDecoration(
                        labelText: 'कमेटी ग्रुप का नाम',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _receiverNameController,
                            decoration: const InputDecoration(
                              labelText: 'Authorized Payment Receiver Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _receiverUpiController,
                            decoration: const InputDecoration(
                              labelText: 'Receiver UPI ID',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _firstInstallmentDateController,
                      decoration: const InputDecoration(
                        labelText: 'पहली किस्त की तारीख (YYYY-MM-DD)',
                        prefixIcon: Icon(Icons.event),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedFrequency,
                            decoration: const InputDecoration(
                              labelText: 'किस्त Frequency',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Daily', child: Text('दैनिक (Daily)')),
                              DropdownMenuItem(value: 'Weekly', child: Text('साप्ताहिक (Weekly - 4/माह)')),
                              DropdownMenuItem(value: 'Monthly', child: Text('मासिक (Monthly)')),
                              DropdownMenuItem(value: 'Quarterly', child: Text('त्रैमासिक (Quarterly)')),
                            ],
                            onChanged: (val) => setState(() => _selectedFrequency = val!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'कुल महीने (Duration)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'गणना प्रीव्यू: $_selectedFrequency प्लान में ${_durationController.text} माह = कुल $previewTotalInstallments किस्तें बनेंगी।',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _groupAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'प्रति किस्त राशि (₹)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedPenaltyType,
                      decoration: const InputDecoration(
                        labelText: 'लेट पेनल्टी नियम चुनें (Penalty Mode)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'FIXED', child: Text('फिक्स्ड राशि (Fixed ₹ per late)')),
                        DropdownMenuItem(value: 'PERCENT_INSTALLMENT', child: Text('किस्त राशि का % (% of Installment)')),
                        DropdownMenuItem(
                          value: 'ESCALATED_AFTER_2_DUE',
                          child: Text('2 किस्त बकाया के बाद कुल बकाया का %'),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedPenaltyType = val!),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _penaltyValueController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: _selectedPenaltyType == 'FIXED'
                                  ? 'फिक्स्ड पेनल्टी राशि (₹)'
                                  : 'सामान्य लेट पेनल्टी (%)',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        if (_selectedPenaltyType == 'ESCALATED_AFTER_2_DUE') ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _penaltyAfter2DueController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '2 Due के बाद कुल बकाया का %',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_createdInviteCode != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'नया Group Code: $_createdInviteCode',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _sendWhatsAppMessage(
                                'नमस्ते! हमारी कमेटी "${_createdGroupName ?? ''}" में जुड़ने के लिए यह Invite Code दर्ज करें:\nGroup Code: *$_createdInviteCode*',
                              ),
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('WhatsApp भेजें'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _createGroup,
                        icon: const Icon(Icons.group_add),
                        label: const Text('नया ग्रुप बनाएं व ऑटोमेशन शुरू करें'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SECTION 6: ग्रुप में जुड़ें
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('6. ग्रुप में जुड़ें (Join Group)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _inviteCodeController,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp पर मिला Group Code दर्ज करें',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _joinGroup,
                        icon: const Icon(Icons.login),
                        label: const Text('ग्रुप में जुड़ें'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBox(String title, String value, Color color) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 17, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}