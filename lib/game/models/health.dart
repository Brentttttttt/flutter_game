import 'dart:math' as math;

class Health {
  Health(this.maxHealth) : currentHealth = maxHealth;

  int maxHealth;
  int currentHealth;

  bool get isDepleted => currentHealth <= 0;

  double get ratio => maxHealth == 0 ? 0 : currentHealth / maxHealth;

  void increaseMaximum(int amount, {int restore = 0}) {
    if (amount <= 0) return;
    maxHealth += amount;
    currentHealth = math.min(maxHealth, currentHealth + math.max(0, restore));
  }

  bool takeDamage(int amount) {
    if (amount <= 0 || isDepleted) {
      return false;
    }

    currentHealth = math.max(0, currentHealth - amount);
    return true;
  }
}
