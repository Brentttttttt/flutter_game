import 'dart:ui';

enum CombatEffectKind { arcaneImpact, fireExplosion }

class CombatEffect {
  CombatEffect(this.position, this.kind);
  final Offset position;
  final CombatEffectKind kind;
  double age = 0;
  int get frameCount => kind == CombatEffectKind.arcaneImpact ? 8 : 7;
  double get fps => kind == CombatEffectKind.arcaneImpact ? 24 : 16;
  bool get isFinished => age >= frameCount / fps;
  int get frame => (age * fps).floor().clamp(0, frameCount - 1);
}

class DamageNumber {
  DamageNumber(this.position, this.damage, {this.isFire = false});
  final Offset position;
  final int damage;
  final bool isFire;
  double age = 0;
  static const duration = 0.65;
  bool get isFinished => age >= duration;
  double get opacity => (1 - age / duration).clamp(0, 1);
}
