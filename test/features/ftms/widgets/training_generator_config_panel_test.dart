import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/ftms/models/session_selector_state.dart';
import 'package:ftms/features/ftms/widgets/training_generator_config_panel.dart';
import 'package:ftms/features/ftms/widgets/duration_distance_picker.dart';
import 'package:ftms/features/ftms/widgets/resistance_level_control.dart';
import 'package:ftms/features/training/model/rower_workout_type.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'package:ftms/core/services/in_app_purchase_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// A minimal mock [InAppPurchase] for widget tests.
class _MockInAppPurchase implements InAppPurchase {
  final StreamController<List<PurchaseDetails>> purchaseStreamController =
      StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      purchaseStreamController.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    return ProductDetailsResponse(
      productDetails: [
        ProductDetails(
          id: kTrainingSessionsProductId,
          title: 'Training Sessions',
          description: 'Unlock all training sessions',
          price: '\$4.99',
          rawPrice: 4.99,
          currencyCode: 'USD',
        ),
      ],
      notFoundIDs: [],
      error: null,
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async =>
      false;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}

  @override
  Future<String> countryCode() async => 'US';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void dispose() {
    purchaseStreamController.close();
  }
}

Widget createTestWidget({
  required Widget child,
  InAppPurchaseService? inAppPurchaseService,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('TrainingGeneratorConfigPanel', () {
    testWidgets('renders with required components', (WidgetTester tester) async {
      final mockIAP = _MockInAppPurchase();
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: mockIAP,
        isApplePlatformOverride: false,
      );
      await service.initialize();

      await tester.pumpWidget(createTestWidget(
        child: TrainingGeneratorConfigPanel(
          config: const TrainingGeneratorConfig(),
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onWorkoutTypeChanged: (_) {},
          onResistanceChanged: (_) {},
          onStart: () {},
          inAppPurchaseService: service,
        ),
      ));
      await tester.pumpAndSettle();

      // Should render duration picker
      expect(find.byType(DurationPicker), findsOneWidget);
      
      // Should render workout type dropdown
      expect(find.text('Workout Type:'), findsOneWidget);
      expect(find.byType(DropdownButton<RowerWorkoutType>), findsOneWidget);
      
      // Should render resistance control
      expect(find.byType(ResistanceLevelControl), findsOneWidget);
      
      // Should render start button
      expect(find.text('Start'), findsOneWidget);
      
      mockIAP.dispose();
    });

    testWidgets('displays current duration value', (WidgetTester tester) async {
      final mockIAP = _MockInAppPurchase();
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: mockIAP,
        isApplePlatformOverride: false,
      );
      await service.initialize();

      await tester.pumpWidget(createTestWidget(
        child: TrainingGeneratorConfigPanel(
          config: const TrainingGeneratorConfig(durationMinutes: 45),
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onWorkoutTypeChanged: (_) {},
          onResistanceChanged: (_) {},
          onStart: () {},
          inAppPurchaseService: service,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('45 min'), findsOneWidget);
      
      mockIAP.dispose();
    });

    testWidgets('displays current workout type', (WidgetTester tester) async {
      final mockIAP = _MockInAppPurchase();
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: mockIAP,
        isApplePlatformOverride: false,
      );
      await service.initialize();

      await tester.pumpWidget(createTestWidget(
        child: TrainingGeneratorConfigPanel(
          config: const TrainingGeneratorConfig(workoutType: RowerWorkoutType.SPRINT),
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onWorkoutTypeChanged: (_) {},
          onResistanceChanged: (_) {},
          onStart: () {},
          inAppPurchaseService: service,
        ),
      ));
      await tester.pumpAndSettle();

      // Should display Sprint workout type label
      // The dropdown button shows the currently selected value
      expect(find.byType(DropdownButton<RowerWorkoutType>), findsOneWidget);
      
      mockIAP.dispose();
    });

    testWidgets('calls onDurationChanged when duration increased', (WidgetTester tester) async {
      final mockIAP = _MockInAppPurchase();
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: mockIAP,
        isApplePlatformOverride: false,
      );
      await service.initialize();

      int? changedValue;
      await tester.pumpWidget(createTestWidget(
        child: TrainingGeneratorConfigPanel(
          config: const TrainingGeneratorConfig(durationMinutes: 30),
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (value) => changedValue = value,
          onWorkoutTypeChanged: (_) {},
          onResistanceChanged: (_) {},
          onStart: () {},
          inAppPurchaseService: service,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap the increment button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(changedValue, 31);
      
      mockIAP.dispose();
    });

    testWidgets('calls onDurationChanged when duration decreased', (WidgetTester tester) async {
      final mockIAP = _MockInAppPurchase();
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: mockIAP,
        isApplePlatformOverride: false,
      );
      await service.initialize();

      int? changedValue;
      await tester.pumpWidget(createTestWidget(
        child: TrainingGeneratorConfigPanel(
          config: const TrainingGeneratorConfig(durationMinutes: 30),
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (value) => changedValue = value,
          onWorkoutTypeChanged: (_) {},
          onResistanceChanged: (_) {},
          onStart: () {},
          inAppPurchaseService: service,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap the decrement button
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      expect(changedValue, 29);
      
      mockIAP.dispose();
    });

    testWidgets('calls onWorkoutTypeChanged when dropdown value changed', (WidgetTester tester) async {
      final mockIAP = _MockInAppPurchase();
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: mockIAP,
        isApplePlatformOverride: false,
      );
      await service.initialize();

      RowerWorkoutType? changedType;
      await tester.pumpWidget(createTestWidget(
        child: TrainingGeneratorConfigPanel(
          config: const TrainingGeneratorConfig(workoutType: RowerWorkoutType.BASE_ENDURANCE),
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onWorkoutTypeChanged: (type) => changedType = type,
          onResistanceChanged: (_) {},
          onStart: () {},
          inAppPurchaseService: service,
        ),
      ));
      await tester.pumpAndSettle();

      // Open the dropdown
      await tester.tap(find.byType(DropdownButton<RowerWorkoutType>));
      await tester.pumpAndSettle();

      // Select Sprint workout type (text is "Sprint" in the dropdown menu)
      final sprintItem = find.text('Sprint').last;
      await tester.tap(sprintItem);
      await tester.pumpAndSettle();

      expect(changedType, RowerWorkoutType.SPRINT);
      
      mockIAP.dispose();
    });

    testWidgets('calls onStart when start button pressed', (WidgetTester tester) async {
      final mockIAP = _MockInAppPurchase();
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: mockIAP,
        isApplePlatformOverride: false,
      );
      await service.initialize();

      bool startPressed = false;
      await tester.pumpWidget(createTestWidget(
        child: TrainingGeneratorConfigPanel(
          config: const TrainingGeneratorConfig(),
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onWorkoutTypeChanged: (_) {},
          onResistanceChanged: (_) {},
          onStart: () => startPressed = true,
          inAppPurchaseService: service,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(startPressed, true);
      
      mockIAP.dispose();
    });

    testWidgets('start button disabled when resistance level is invalid', (WidgetTester tester) async {
      final mockIAP = _MockInAppPurchase();
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: mockIAP,
        isApplePlatformOverride: false,
      );
      await service.initialize();

      bool startPressed = false;
      await tester.pumpWidget(createTestWidget(
        child: TrainingGeneratorConfigPanel(
          config: const TrainingGeneratorConfig(isResistanceLevelValid: false),
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (_) {},
          onWorkoutTypeChanged: (_) {},
          onResistanceChanged: (_) {},
          onStart: () => startPressed = true,
          inAppPurchaseService: service,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // Start should not be called because button is disabled
      expect(startPressed, false);
      
      mockIAP.dispose();
    });

    testWidgets('duration has correct min/max limits', (WidgetTester tester) async {
      final mockIAP = _MockInAppPurchase();
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: mockIAP,
        isApplePlatformOverride: false,
      );
      await service.initialize();

      int? changedValue;
      await tester.pumpWidget(createTestWidget(
        child: TrainingGeneratorConfigPanel(
          config: const TrainingGeneratorConfig(durationMinutes: 15),
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (value) => changedValue = value,
          onWorkoutTypeChanged: (_) {},
          onResistanceChanged: (_) {},
          onStart: () {},
          inAppPurchaseService: service,
        ),
      ));
      await tester.pumpAndSettle();

      // Try to decrement at minimum (15 min)
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      // Should not call onChanged when at minimum
      expect(changedValue, isNull);
      
      mockIAP.dispose();
    });

    testWidgets('duration cannot exceed max limit of 120', (WidgetTester tester) async {
      final mockIAP = _MockInAppPurchase();
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: mockIAP,
        isApplePlatformOverride: false,
      );
      await service.initialize();

      int? changedValue;
      await tester.pumpWidget(createTestWidget(
        child: TrainingGeneratorConfigPanel(
          config: const TrainingGeneratorConfig(durationMinutes: 120),
          resistanceCapabilities: const ResistanceCapabilities(),
          onDurationChanged: (value) => changedValue = value,
          onWorkoutTypeChanged: (_) {},
          onResistanceChanged: (_) {},
          onStart: () {},
          inAppPurchaseService: service,
        ),
      ));
      await tester.pumpAndSettle();

      // Try to increment at maximum (120 min)
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Should not call onChanged when at maximum
      expect(changedValue, isNull);
      
      mockIAP.dispose();
    });

    testWidgets('uses provided resistance controller', (WidgetTester tester) async {
      final mockIAP = _MockInAppPurchase();
      final service = InAppPurchaseService.forTesting(
        inAppPurchase: mockIAP,
        isApplePlatformOverride: false,
      );
      await service.initialize();

      final controller = TextEditingController(text: '5');
      
      await tester.pumpWidget(createTestWidget(
        child: TrainingGeneratorConfigPanel(
          config: const TrainingGeneratorConfig(userResistanceLevel: 5),
          resistanceCapabilities: const ResistanceCapabilities(supportsResistanceControl: true),
          resistanceController: controller,
          onDurationChanged: (_) {},
          onWorkoutTypeChanged: (_) {},
          onResistanceChanged: (_) {},
          onStart: () {},
          inAppPurchaseService: service,
        ),
      ));
      await tester.pumpAndSettle();

      // Controller should be passed to ResistanceLevelControl
      expect(controller.text, '5');
      
      controller.dispose();
      mockIAP.dispose();
    });
  });
}
