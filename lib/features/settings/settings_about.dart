
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:visual_song_book/features/settings/settings_card_shell.dart';

class AboutCard extends StatefulWidget {
  const AboutCard({super.key});

  @override
  State<AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<AboutCard> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SettingsCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/logo.png',
              width: 52,
              height: 52,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visual Song Book',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Song management, Bible reader & live projection for church worship teams.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (_version.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _version,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      'by BenjaNetan',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

