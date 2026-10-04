/// What the encounter sheet came back with.
typedef EncounterAnswer = ({DateTime? metOn, String place});

/// What the next-step sheet came back with. [remindAt] is the reminder time
/// the sheet showed — null for no reminder — so what is saved is what the
/// user read. [remove] means "drop this step", and only the edit sheet offers
/// it.
typedef StepAnswer = ({
  String title,
  DateTime dueOn,
  DateTime? remindAt,
  bool remove,
});
