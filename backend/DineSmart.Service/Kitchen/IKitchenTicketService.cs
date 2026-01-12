using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using DtoKitchenTicketStatus = DineSmart.Dto.Kitchen.KitchenTicketStatus;

namespace DineSmart.Service.Kitchen;

/// <summary>
/// Describes read/write operations that can be performed on kitchen tickets.
/// </summary>
public interface IKitchenTicketService
{
    /// <summary>
    /// Retrieves the current status of a kitchen ticket.
    /// </summary>
    /// <param name="ticketId">Unique identifier of the ticket.</param>
    /// <param name="cancellationToken">Token that indicates whether the caller no longer needs the result.</param>
    /// <returns>The DTO representation of the ticket status.</returns>
    Task<DtoKitchenTicketStatus> GetStatusAsync(Guid ticketId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Updates the status of a kitchen ticket.
    /// </summary>
    /// <param name="ticketId">Unique identifier of the ticket.</param>
    /// <param name="newStatus">Updated status for the ticket expressed in DTO form.</param>
    /// <param name="cancellationToken">Token that indicates whether the caller no longer needs the result.</param>
    Task UpdateStatusAsync(Guid ticketId, DtoKitchenTicketStatus newStatus, CancellationToken cancellationToken = default);

    /// <summary>
    /// Returns the identifiers of all tickets that currently match the provided status.
    /// </summary>
    /// <param name="status">Status filter, expressed in DTO form.</param>
    /// <param name="cancellationToken">Token that indicates whether the caller no longer needs the result.</param>
    Task<IReadOnlyCollection<Guid>> GetTicketsByStatusAsync(DtoKitchenTicketStatus status, CancellationToken cancellationToken = default);
}
