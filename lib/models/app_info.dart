import 'package:flutter/material.dart';

class AppInfo {
  final String packageName;
  final String name;
  final IconData icon;
  final List<Color> gradientColors;
  final String category;

  final String? iconPath;

  const AppInfo({
    required this.packageName,
    required this.name,
    required this.icon,
    required this.gradientColors,
    this.category = 'App',
    this.iconPath,
  });

  AppInfo copyWith({
    String? packageName,
    String? name,
    IconData? icon,
    List<Color>? gradientColors,
    String? category,
    String? iconPath,
  }) {
    return AppInfo(
      packageName: packageName ?? this.packageName,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      gradientColors: gradientColors ?? this.gradientColors,
      category: category ?? this.category,
      iconPath: iconPath ?? this.iconPath,
    );
  }

  static AppInfo fromPackage(String pkg, [String? iconPath]) {
    final lower = pkg.toLowerCase();
    String name = _resolveName(pkg);
    IconData icon = _resolveIcon(lower, name.toLowerCase());
    List<Color> colors = _resolveColors(lower, name.toLowerCase());
    String category = _resolveCategory(lower, name.toLowerCase());

    return AppInfo(
      packageName: pkg,
      name: name,
      icon: icon,
      gradientColors: colors,
      category: category,
      iconPath: iconPath,
    );
  }

  static String _resolveName(String pkg) {
    final lower = pkg.toLowerCase();

    // Well-known popular app mappings
    if (lower == 'com.google.android.calculator' ||
        lower == 'com.android.calculator2') return 'Calculator';
    if (lower == 'com.android.chrome') return 'Chrome';
    if (lower == 'com.google.android.youtube') return 'YouTube';
    if (lower == 'com.openai.chatgpt') return 'ChatGPT';
    if (lower == 'com.anthropic.claude') return 'Claude';
    if (lower == 'ai.perplexity.app.android') return 'Perplexity';
    if (lower == 'com.whatsapp') return 'WhatsApp';
    if (lower.contains('telegram')) return 'Telegram';
    if (lower == 'org.mozilla.firefox') return 'Firefox';
    if (lower == 'com.github.android') return 'GitHub';
    if (lower == 'com.discord') return 'Discord';
    if (lower == 'org.videolan.vlc') return 'VLC';
    if (lower == 'com.ubercab') return 'Uber';
    if (lower == 'com.google.android.gm') return 'Gmail';
    if (lower.contains('maps')) return 'Maps';
    if (lower.contains('photos')) return 'Photos';
    if (lower.contains('nbu.files') || lower == 'com.android.filemanager')
      return 'Files';
    if (lower.contains('camera')) return 'Camera';
    if (lower.contains('dialer') || lower.contains('phone')) return 'Phone';
    if (lower.contains('messaging')) return 'Messages';
    if (lower.contains('settings')) return 'Settings';
    if (lower.contains('deskclock')) return 'Clock';
    if (lower.contains('spotify')) return 'Spotify';
    if (lower.contains('netflix')) return 'Netflix';
    if (lower.contains('linkedin')) return 'LinkedIn';
    if (lower.contains('reddit')) return 'Reddit';
    if (lower.contains('instagram')) return 'Instagram';
    if (lower.contains('termux')) return 'Termux';
    if (lower.contains('word')) return 'Word';
    if (lower.contains('docs')) return 'Docs';
    if (lower.contains('freefire')) return 'Free Fire';
    if (lower.contains('kdeconnect')) return 'KDE Connect';
    if (lower.contains('newpipe')) return 'NewPipe';
    if (lower.contains('protonmail')) return 'Proton Mail';
    if (lower.contains('protonvpn')) return 'Proton VPN';
    if (lower.contains('bitwarden')) return 'Bitwarden';
    if (lower.contains('flipkart')) return 'Flipkart';
    if (lower.contains('amazon')) return 'Amazon';
    if (lower.contains('canva')) return 'Canva';
    if (lower.contains('steam')) return 'Steam';
    if (lower.contains('hotstar')) return 'Disney+ Hotstar';
    if (lower.contains('phonepe')) return 'PhonePe';
    if (lower.contains('whereismytrain')) return 'Where Is My Train';

    // Smart fallback: discard generic words like android, mobile, app, client
    final parts = pkg.split('.');
    String candidate = parts.last;
    if (const {
      'android',
      'app',
      'client',
      'mobile',
      'frontend',
      'ui',
      'passenger',
      'customer'
    }.contains(candidate.toLowerCase())) {
      if (parts.length >= 2) {
        candidate = parts[parts.length - 2];
      }
    }

    if (candidate.isEmpty) return pkg;
    return candidate[0].toUpperCase() + candidate.substring(1);
  }

  static IconData _resolveIcon(String lower, String name) {
    if (name.contains('calculator')) return Icons.calculate_rounded;
    if (name.contains('chrome') ||
        name.contains('firefox') ||
        name.contains('browser')) return Icons.language_rounded;
    if (name.contains('youtube') ||
        name.contains('vlc') ||
        name.contains('video') ||
        name.contains('media') ||
        name.contains('hotstar')) {
      return Icons.play_circle_fill_rounded;
    }
    if (name.contains('chatgpt') ||
        name.contains('claude') ||
        name.contains('perplexity')) return Icons.psychology_rounded;
    if (name.contains('camera')) return Icons.camera_alt_rounded;
    if (name.contains('settings')) return Icons.settings_rounded;
    if (name.contains('contacts')) return Icons.contacts_rounded;
    if (name.contains('photos') ||
        name.contains('gallery') ||
        name.contains('canva') ||
        name.contains('instagram')) {
      return Icons.photo_library_rounded;
    }
    if (name.contains('files') ||
        name.contains('drive') ||
        name.contains('word') ||
        name.contains('docs')) {
      return Icons.folder_rounded;
    }
    if (name.contains('clock')) return Icons.access_time_filled_rounded;
    if (name.contains('mail') || name.contains('gmail'))
      return Icons.mail_rounded;
    if (name.contains('maps') ||
        name.contains('train') ||
        name.contains('uber')) return Icons.map_rounded;
    if (name.contains('messages') ||
        name.contains('whatsapp') ||
        name.contains('telegram') ||
        name.contains('discord')) {
      return Icons.chat_bubble_rounded;
    }
    if (name.contains('phone') || name.contains('dialer'))
      return Icons.call_rounded;
    if (name.contains('music') || name.contains('spotify'))
      return Icons.music_note_rounded;
    if (name.contains('terminal') || name.contains('termux'))
      return Icons.terminal_rounded;
    if (name.contains('github')) return Icons.code_rounded;
    if (name.contains('steam') ||
        name.contains('game') ||
        name.contains('fire')) return Icons.sports_esports_rounded;
    if (name.contains('pay') ||
        name.contains('wallet') ||
        name.contains('bank')) return Icons.account_balance_wallet_rounded;
    return Icons.apps_rounded;
  }

  static List<Color> _resolveColors(String lower, String name) {
    if (name.contains('calculator'))
      return const [Color(0xFF22C55E), Color(0xFF16A34A)];
    if (name.contains('chrome'))
      return const [Color(0xFF3B82F6), Color(0xFF1D4ED8)];
    if (name.contains('firefox'))
      return const [Color(0xFFFF7139), Color(0xFFFF4F00)];
    if (name.contains('youtube'))
      return const [Color(0xFFEF4444), Color(0xFFDC2626)];
    if (name.contains('chatgpt'))
      return const [Color(0xFF10A37F), Color(0xFF0D8265)];
    if (name.contains('claude'))
      return const [Color(0xFFD97757), Color(0xFFB8593A)];
    if (name.contains('whatsapp'))
      return const [Color(0xFF25D366), Color(0xFF128C7E)];
    if (name.contains('telegram'))
      return const [Color(0xFF229ED9), Color(0xFF0088CC)];
    if (name.contains('discord'))
      return const [Color(0xFF5865F2), Color(0xFF4752C4)];
    if (name.contains('vlc'))
      return const [Color(0xFFFF8800), Color(0xFFFF5500)];
    if (name.contains('github'))
      return const [Color(0xFF475569), Color(0xFF1E293B)];
    if (name.contains('camera'))
      return const [Color(0xFFEC4899), Color(0xFFDB2777)];
    if (name.contains('settings'))
      return const [Color(0xFF64748B), Color(0xFF475569)];
    if (name.contains('gmail'))
      return const [Color(0xFFEA4335), Color(0xFFC5221F)];
    if (name.contains('maps'))
      return const [Color(0xFF34A853), Color(0xFF1E8E3E)];
    if (name.contains('spotify'))
      return const [Color(0xFF1DB954), Color(0xFF1AA34A)];

    final hash = name.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    const palettes = [
      [Color(0xFF6366F1), Color(0xFF4F46E5)],
      [Color(0xFF14B8A6), Color(0xFF0D9488)],
      [Color(0xFFF97316), Color(0xFFEA580C)],
      [Color(0xFFA855F7), Color(0xFF9333EA)],
      [Color(0xFF0EA5E9), Color(0xFF0284C7)],
      [Color(0xFFE11D48), Color(0xFFBE123C)],
      [Color(0xFF06B6D4), Color(0xFF0891B2)],
      [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    ];
    return palettes[hash % palettes.length];
  }

  static String _resolveCategory(String lower, String name) {
    if (name.contains('camera') ||
        name.contains('photos') ||
        name.contains('youtube') ||
        name.contains('vlc') ||
        name.contains('music')) {
      return 'Media';
    }
    if (name.contains('messages') ||
        name.contains('whatsapp') ||
        name.contains('telegram') ||
        name.contains('discord') ||
        name.contains('phone')) {
      return 'Social';
    }
    if (name.contains('calculator') ||
        name.contains('clock') ||
        name.contains('files') ||
        name.contains('termux')) {
      return 'Tools';
    }
    if (name.contains('settings') || name.contains('play')) {
      return 'System';
    }
    return 'Apps';
  }
}
