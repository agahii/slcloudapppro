using DataKitchenTicketStatus = DineSmart.Data.Enums.KitchenTicketStatus;
using DtoKitchenTicketStatus = DineSmart.Dto.Kitchen.KitchenTicketStatus;

namespace DineSmart.Service;

/// <summary>
/// Provides helpers for translating kitchen ticket statuses between layers while
/// avoiding ambiguous references to the identically named enums.
/// </summary>
public static class KitchenTicketStatusMapper
{
    /// <summary>
    /// Maps the DTO status value received from the API layer into the domain enum
    /// without relying on ambiguous <c>using</c> directives.
    /// </summary>
    public static DataKitchenTicketStatus ToDomainStatus(DtoKitchenTicketStatus dtoStatus) => dtoStatus switch
    {
        DtoKitchenTicketStatus.Pending => DataKitchenTicketStatus.Pending,
        DtoKitchenTicketStatus.InProgress => DataKitchenTicketStatus.InProgress,
        DtoKitchenTicketStatus.Ready => DataKitchenTicketStatus.Ready,
        DtoKitchenTicketStatus.Completed => DataKitchenTicketStatus.Completed,
        DtoKitchenTicketStatus.Cancelled => DataKitchenTicketStatus.Cancelled,
        _ => throw new System.ArgumentOutOfRangeException(nameof(dtoStatus), dtoStatus, "Unsupported kitchen ticket status value.")
    };

    /// <summary>
    /// Converts the domain status back into its DTO counterpart.
    /// </summary>
    public static DtoKitchenTicketStatus ToDtoStatus(DataKitchenTicketStatus domainStatus) => domainStatus switch
    {
        DataKitchenTicketStatus.Pending => DtoKitchenTicketStatus.Pending,
        DataKitchenTicketStatus.InProgress => DtoKitchenTicketStatus.InProgress,
        DataKitchenTicketStatus.Ready => DtoKitchenTicketStatus.Ready,
        DataKitchenTicketStatus.Completed => DtoKitchenTicketStatus.Completed,
        DataKitchenTicketStatus.Cancelled => DtoKitchenTicketStatus.Cancelled,
        _ => throw new System.ArgumentOutOfRangeException(nameof(domainStatus), domainStatus, "Unsupported kitchen ticket status value.")
    };
}
