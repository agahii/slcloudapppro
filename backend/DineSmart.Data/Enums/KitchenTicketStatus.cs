namespace DineSmart.Data.Enums;

/// <summary>
/// Represents the state of a kitchen ticket as stored by the persistence layer.
/// </summary>
public enum KitchenTicketStatus
{
    Pending = 0,
    InProgress = 1,
    Ready = 2,
    Completed = 3,
    Cancelled = 4
}
