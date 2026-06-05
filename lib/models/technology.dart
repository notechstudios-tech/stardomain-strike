enum Technology {
  advancedWeapons,
  advancedStarDefence,
  advancedShipDefence,
  improvedEngines,
  improvedProduction,
  improvedWeaponStrength,
  improvedWeaponCapacity,
  quantumAttack,
  quantumVision,
  surpriseAttack,
  surpriseDefence,
  alterReality,
}

extension TechnologyInfo on Technology {
  String get displayName => switch (this) {
    Technology.advancedWeapons        => 'Advanced Weapons',
    Technology.advancedStarDefence    => 'Advanced Star Defence',
    Technology.advancedShipDefence    => 'Advanced Ship Defence',
    Technology.improvedEngines        => 'Improved Engines',
    Technology.improvedProduction     => 'Improved Production',
    Technology.improvedWeaponStrength => 'Improved Weapon Strength',
    Technology.improvedWeaponCapacity => 'Improved Weapon Capacity',
    Technology.quantumAttack          => 'Quantum Attack',
    Technology.quantumVision          => 'Quantum Vision',
    Technology.surpriseAttack         => 'Surprise Attack',
    Technology.surpriseDefence        => 'Surprise Defence',
    Technology.alterReality           => 'Alter Reality',
  };

  String get description => switch (this) {
    Technology.advancedWeapons        => '+1 bonus to every attack roll your fleets make.',
    Technology.advancedStarDefence    => '+1 defence rating for all your stars.',
    Technology.advancedShipDefence    => 'Your ships are 1 point harder to destroy in battle.',
    Technology.improvedEngines        => 'Your fleets travel twice as fast across the galaxy.',
    Technology.improvedProduction     => 'Each of your stars produces 1 extra ship per turn.',
    Technology.improvedWeaponStrength => 'Lower attack threshold — your weapons hit more accurately.',
    Technology.improvedWeaponCapacity => 'Your weapons can roll higher values (d11 instead of d10).',
    Technology.quantumAttack          => '10% chance each of your attack rolls is doubled.',
    Technology.quantumVision          => 'Tap any star or fleet marker to reveal its stats.',
    Technology.surpriseAttack         => 'Destroy one defender for free before battle begins.',
    Technology.surpriseDefence        => 'Destroy one attacker for free before battle begins.',
    Technology.alterReality           => '10% chance enemy ships join your fleet instead of fighting.',
  };
}
