import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The blue check shown after the name of a verified (admin) channel.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Verified',
      child: ExcludeSemantics(
        child: Icon(
          Icons.verified_rounded,
          size: size,
          color: AppColors.verified,
        ),
      ),
    );
  }
}

/// A channel name with the verified check after it when [verified] is true.
class ChannelName extends StatelessWidget {
  const ChannelName(
    this.name, {
    super.key,
    required this.verified,
    this.style,
    this.badgeSize = 16,
  });

  final String name;
  final bool verified;
  final TextStyle? style;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(name, overflow: TextOverflow.ellipsis, style: style),
        ),
        if (verified) ...[
          const SizedBox(width: 4),
          VerifiedBadge(size: badgeSize),
        ],
      ],
    );
  }
}
