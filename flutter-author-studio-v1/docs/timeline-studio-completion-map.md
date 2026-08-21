# Timeline Studio completion map

## Existing architecture discovered

- The app already contains the canonical timeline domain in `lib/timeline_domain.dart` and the project-scoped service layer in `lib/timeline_service.dart`.
- Timeline data persists through the shared Universal Record architecture and Drift repository, not through a separate timeline database.
- `TimelineRecordTypes` registers project-scoped timeline record types under the base `timeline-record` type and hooks them into the shared record registry.
- `TimelineQueryService` and `TimelineService.validateTemporal()` provide the current chronological and validation logic that the Studio should consume.
- The project-level repository is `authorOsRepository` from `lib/persistence/authoros_database.dart`.

## Files reused

- `lib/timeline_service.dart`
- `lib/timeline_domain.dart`
- `lib/core/timeline_record_types.dart`
- `lib/persistence/authoros_database.dart`
- `lib/main.dart`
- `test/timeline_test.dart`

## Files created

- `lib/timeline_studio_view.dart`
- `test/timeline_studio_view_test.dart`
- `docs/timeline-studio-completion-map.md`

## Files modified

- `lib/main.dart`

## Files deleted

- None.

## Service integration

The Studio uses the existing `TimelineService` by constructing it with the active project id and repository and calling `query.all()` to load current timeline records. Event creation/retrieval/edit/delete are routed through the same service layer rather than a parallel timeline implementation.

## Persistence integration

- Persistence remains in the shared Drift-connected domain repository.
- The Studio does not create any new schema or migration.
- Timeline records remain project-scoped and are returned through the existing `RecordService` / `TimelineQueryService` APIs.

## UI integration

- The navigation item resolves to `TimelineStudioView` in `lib/main.dart`.
- The view renders a project-scoped chronology with a loading state, empty state, populated state, and error state.
- Event cards show title, summary, type, status, and date metadata while preserving the app theme.

## Navigation integration

- The sidebar story section now opens the real Timeline Studio, so the user enters the actual studio instead of a disconnected placeholder.

## Tests added

- `test/timeline_studio_view_test.dart` covers the empty state, populated state, and action menu UI.
- Existing `test/timeline_test.dart` continues to validate project isolation and timeline state persistence.

## Verification results

- `flutter analyze`: passes.
- `flutter test`: passes.
- `flutter build web --release`: passes.
- `flutter build windows --release`: passes.

## Known limitations

- The current Studio is intentionally built as a project-scoped timeline workspace over the existing record model. It does not add a separate timeline database or relationship store.
- Event creation/editing is lightweight and follows the existing service contract; deeper timeline editing can be extended through the same domain if needed.

## Decisions made

- Reused the existing timeline service and record persistence instead of introducing a second timeline architecture.
- Kept timeline rendering in a dedicated view file while feeding it through the live domain service.
- Preserved the app's theme composition and Material 3 tokens rather than creating custom theme data.
