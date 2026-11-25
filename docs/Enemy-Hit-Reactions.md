# Enemy hit reaction foundation

The procedural enemy visual rig now responds when its gameplay actor receives a non-lethal hit.

## Event path

1. The weapon/projectile system calls `Enemy.take_hit(shape_index, damage)`.
2. The enemy applies the existing hit-zone damage multiplier and updates health.
3. The enemy emits `hit_received` with the enemy, collision shape index and final damage.
4. `EnemyVisual` listens for that signal and starts a short stagger reaction.
5. The visual rig leans and twists, with a small head/arm response; the side of the recoil is selected relative to the player's direction.
6. The reaction eases back to the normal procedural pose over approximately 0.34 seconds.

## Safety and separation

- The reaction is presentation-only. It does not alter enemy health, hit zones, navigation, movement velocity, perception or weapon accuracy.
- Existing head, torso and limb collision shapes remain owned by the enemy actor.
- Lethal hits continue through the existing death state and collapse path rather than relying on a non-lethal stagger.
- If there is no player reference, the reaction still plays with its default direction.

## Automated coverage

`tests/enemy_visual.gd` checks that a registered non-lethal hit starts the reaction, that the torso visibly recoils, and that the rig returns to its neutral pose after the reaction window.

## Limitations

This is a procedural pose adjustment on the existing primitive humanoid rig, not an authored animation clip. It does not yet select a distinct animation by head/torso/limb hit, use a skeletal animation tree, simulate impact physics, blend into a ragdoll, or provide multiple death animations. Windows visual review is still required.
