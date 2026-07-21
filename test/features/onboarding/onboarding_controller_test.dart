import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/onboarding/data/onboarding_repository.dart';
import 'package:forge_app/features/onboarding/domain/onboarding_profile.dart';
import 'package:forge_app/features/onboarding/presentation/onboarding_controller.dart';

void main() {
  test('restores an interrupted onboarding step', () async {
    final repository = _MemoryOnboardingRepository(
      const OnboardingProfile(goal: OnboardingGoal.productive, currentStep: 4),
    );
    final controller = OnboardingController(repository);

    await controller.initialize();

    expect(controller.status, OnboardingStatus.ready);
    expect(controller.profile.currentStep, 4);
    expect(controller.profile.goal, OnboardingGoal.productive);
  });

  test('persists each completed step and selected answers', () async {
    final repository = _MemoryOnboardingRepository();
    final controller = OnboardingController(repository);
    await controller.initialize();

    controller.selectGoal(OnboardingGoal.healthier);
    controller.selectDisciplineLevel(DisciplineLevel.improving);
    final saved = await controller.moveTo(3);

    expect(saved, isTrue);
    expect(repository.value.goal, OnboardingGoal.healthier);
    expect(repository.value.disciplineLevel, DisciplineLevel.improving);
    expect(repository.value.currentStep, 3);
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
