/// What the encounter sheet came back with.
typedef EncounterAnswer = ({DateTime? metOn, String place});

/// What the next-step sheet came back with. [remove] means "drop this step",
/// and only the edit sheet offers it.
typedef StepAnswer = ({String title, DateTime dueOn, bool remind, bool remove});
