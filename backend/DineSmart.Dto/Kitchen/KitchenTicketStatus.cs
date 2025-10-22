namespace DineSmart.Dto.Kitchen;

/// <summary>
/// Transport layer representation of a kitchen ticket's lifecycle state.
/// </summary>
public enum KitchenTicketStatus
{
    Pending = 0,
    InProgress = 1,
    Ready = 2,
    Completed = 3,
    Cancelled = 4
}
