import 'package:flutter/material.dart';

import '../models/key_traits.dart';
import '../models/species.dart';
import '../theme.dart';

/// Badge a pillola con la categoria di sicurezza della specie.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge(
    this.category, {
    super.key,
    this.text,
    this.large = false,
  });
  final Category category;
  final String? text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final onLight = category == Category.commestibileItalia;
    final fg = onLight ? const Color(0xFF2B2100) : Colors.white;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 10,
        vertical: large ? 7 : 4,
      ),
      decoration: BoxDecoration(
        color: category.color,
        borderRadius: BorderRadius.circular(20),
        border: category == Category.mortale
            ? Border.all(color: Colors.white54)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (category.icon != null) ...[
            Icon(category.icon, size: large ? 18 : 14, color: fg),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text ?? category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: large ? 14 : 12,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto principale della specie, con segnaposto se manca.
class SpeciesPhotoView extends StatelessWidget {
  const SpeciesPhotoView(
    this.species, {
    super.key,
    this.index = 0,
    this.cacheWidth = 900,
    this.fit = BoxFit.cover,
  });
  final Species species;
  final int index;
  final int cacheWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final placeholder = Container(
      color: p.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(Icons.eco_outlined, size: 40, color: p.inkSoft),
    );
    if (index >= species.photos.length) return placeholder;
    return Image.asset(
      species.photos[index].asset,
      fit: fit,
      cacheWidth: cacheWidth,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

/// Miniatura quadrata dalla cartella asset.
class SpeciesThumb extends StatelessWidget {
  const SpeciesThumb(this.species, {super.key, this.size = 64});
  final Species species;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: size,
      height: size,
      child: SpeciesPhotoView(species, cacheWidth: 240),
    ),
  );
}

/// Riga di caratteri distintivi, compatta, per riconoscere il fungo subito.
class TraitChips extends StatelessWidget {
  const TraitChips(
    this.species, {
    super.key,
    this.max = 7,
    this.showBlurb = true,
  });
  final Species species;
  final int max;
  final bool showBlurb;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final traits = species.keyTraits;
    if (traits.isEmpty) {
      final blurb = showBlurb ? species.fallbackBlurb : null;
      return Text(
        blurb ?? 'Caratteri non riportati nelle fonti consultate.',
        style: TextStyle(
          color: p.inkSoft,
          fontSize: 13,
          height: 1.35,
          fontStyle: blurb == null ? FontStyle.italic : null,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final t in traits.take(max)) TraitChip(t)],
    );
  }
}

class TraitChip extends StatelessWidget {
  const TraitChip(this.trait, {super.key});
  final KeyTrait trait;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final bg = trait.alert ? p.dangerBg : p.surfaceAlt;
    final fg = trait.alert ? p.danger : p.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
        border: trait.alert
            ? Border.all(color: p.danger.withValues(alpha: 0.5))
            : null,
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${trait.label}  ',
              style: TextStyle(
                color: trait.alert ? p.danger : p.inkSoft,
                fontSize: 11.5,
              ),
            ),
            TextSpan(
              text: trait.value,
              style: TextStyle(
                color: fg,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Striscia sottile sempre visibile sotto la barra del titolo.
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: double.infinity,
      color: p.warnBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: p.warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Un supporto informativo, non un verdetto.',
              style: TextStyle(
                color: p.warn,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum AlertKind { danger, caution, info }

/// Riquadro di avviso a tutta larghezza (rosso = pericolo, ambra = cautela).
class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.text,
    this.kind = AlertKind.danger,
    this.icon,
    this.title,
  });
  final String text;
  final String? title;
  final AlertKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (bg, fg, ic) = switch (kind) {
      AlertKind.danger => (p.dangerBg, p.danger, Icons.warning_amber_rounded),
      AlertKind.caution => (p.warnBg, p.warn, Icons.info_outline),
      AlertKind.info => (p.surfaceAlt, p.inkSoft, Icons.info_outline),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? ic, color: fg, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      title!,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                Text(
                  text,
                  style: TextStyle(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
