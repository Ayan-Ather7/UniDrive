import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/driver_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  late String _driverName;
  late String _rideId;
  late String _driverId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final driver = ModalRoute.of(context)?.settings.arguments as DriverModel?;
    _driverName = driver?.name ?? '';
    _rideId     = driver?.id ?? '';
    _driverId   = driver?.driverId ?? '';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    
    final uid = AuthService().currentUid;
    if (uid != null) {
      await DatabaseService().sendMessage(
        rideId: _rideId,
        driverId: _driverId,
        passengerId: uid,
        senderId: uid,
        text: text,
      );
      if (_scroll.hasClients) {
        _scroll.animateTo(0.0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = timestamp.toDate();
    final m = now.minute.toString().padLeft(2, '0');
    final period = now.hour < 12 ? 'AM' : 'PM';
    final hr = now.hour % 12 == 0 ? 12 : now.hour % 12;
    return '$hr:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        leading: BackButton(color: isDark ? Colors.white : Colors.black),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.cyan.withValues(alpha: 0.15),
              child: const Icon(Icons.face_rounded,
                  size: 24, color: AppColors.cyan),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_driverName,
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800, fontSize: 16,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                Row(
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.4), blurRadius: 4)]
                        )).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 800.ms),
                    const SizedBox(width: 6),
                    Text('En Route',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded, color: AppColors.cyan),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Calling driver…')),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Messages ─────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: DatabaseService().streamRideMessages(_rideId, AuthService().currentUid ?? ''),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                // streamRideMessages orders by timestamp descending, so list is reverse
                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == AuthService().currentUid;
                    return RepaintBoundary(
                      child: _Bubble(
                        text: data['text'] ?? '',
                        time: _formatTime(data['timestamp'] as Timestamp?),
                        isMe: isMe,
                        isDark: isDark,
                      ).animate().slideY(begin: 0.2, curve: Curves.easeOutCubic).fadeIn(duration: 300.ms),
                    );
                  },
                );
              }
            ),
          ),

          // ── Input bar ─────────────────────────────────────────────────
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
                  border: Border(
                      top: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : const Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        style: TextStyle(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Type a message…',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppColors.darkSurface.withValues(alpha: 0.5)
                              : AppColors.bgGrey,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                            color: AppColors.blue, shape: BoxShape.circle),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ).animate(target: _ctrl.text.isEmpty ? 0 : 1).scale(end: const Offset(1.1, 1.1)),
                  ],
                ),
              ),
            ),
          ).animate().slideY(begin: 1.0, curve: Curves.easeOutExpo),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text, time;
  final bool isMe, isDark;
  const _Bubble(
      {required this.text,
      required this.time,
      required this.isMe,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.blue
              : isDark
                  ? AppColors.darkCard
                  : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 6),
            bottomRight: Radius.circular(isMe ? 6 : 20),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isMe
                        ? Colors.white
                        : isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                    height: 1.4)),
            const SizedBox(height: 6),
            Text(time,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
