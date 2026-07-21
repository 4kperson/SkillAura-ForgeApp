import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/onboarding/data/onboarding_repository.dart';
import 'package:forge_app/features/onboarding/domain/onboarding_profile.dart';
import 'package:forge_app/features/onboarding/presentation/onboarding_controller.dart';

void main() {
  test('restores an interrupted onboarding step and all goals', () async {
    final repository = _MemoryOnboardingRepository(
      const OnboardingProfile(
        goals: [OnboardingGoal.productive, OnboardingGoal.betterSleep],
        currentStep: 4,
      ),
    );
    final controller = OnboardingController(repository);

    await controller.initialize();

    expect(controller.status, OnboardingStatus.ready);
    expect(controller.profile.currentStep, 4);
    expect(controller.profile.goals, [
      OnboardingGoal.productive,
      OnboardingGoal.betterSleep,
    ]);
  });

  test('persists multiple goals and selected difficulty', () async {
    final repository = _MemoryOnboardingRepository();
    final controller = OnboardingController(repository);
    await controller.initialize();

    controller.toggleGoal(OnboardingGoal.healthier);
    controller.toggleGoal(OnboardingGoal.productive);
    controller.selectDisciplineLevel(DisciplineLevel.improving);
    final saved = await controller.moveTo(3);

    expect(saved, isTrue);
    expect(repository.value.goals, [
      OnboardingGoal.healthier,
      OnboardingGoal.productive,
    ]);
    expect(repository.value.disciplineLevel, DisciplineLevel.improving);
    expect(repository.value.currentStep, 3);
  });

  test('limits goal selection to three and allows deselection', () async {
    final controller = OnboardingController(_MemoryOnboardingRepository());
    await controller.initialize();

    controller.toggleGoal(OnboardingGoal.disciplined);
    controller.toggleGoal(OnboardingGoal.healthier);
    controller.toggleGoal(OnboardingGoal.productive);
    controller.toggleGoal(OnboardingGoal.student);
    expect(controller.profile.goals, hasLength(3));
    expect(controller.profile.goals, isNot(contains(OnboardingGoal.student)));

    controller.toggleGoal(OnboardingGoal.healthier);
    expect(controller.profile.goals, isNot(contains(OnboardingGoal.healthier)));
    expect(controller.profile.goals, hasLength(2));
  });

  test('marks onboarding complete permanently', () async {
    final repository = _MemoryOnboardingRepository();
    final controller = OnboardingController(repository);
    await controller.initialize();

    expect(await controller.complete(), isTrue);

    expect(controller.status, OnboardingStatus.completed);
    expect(repository.value.isCompleted, isTrue);
    expect(repository.value.currentStep, 6);
  });
}

class _MemoryOnboardingRepository implements OnboardingRepository {
  _MemoryOnboardingRepository([this.value = const OnboardingProfile()]);

  OnboardingProfile value;

  @override
  Future<OnboardingProfile> load() async => value;

  @override
  Future<void> save(OnboardingProfile profile) async => value = profile;
}
