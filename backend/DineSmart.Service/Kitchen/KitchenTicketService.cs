using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using DineSmart.Service;
using DataKitchenTicketStatus = DineSmart.Data.Enums.KitchenTicketStatus;
using DtoKitchenTicketStatus = DineSmart.Dto.Kitchen.KitchenTicketStatus;

namespace DineSmart.Service.Kitchen;

/// <summary>
/// Provides an in-memory implementation of <see cref="IKitchenTicketService"/> that demonstrates
/// how to work with the identically named domain and transport layer enums without triggering
/// ambiguous reference compiler errors.
/// </summary>
public class KitchenTicketService : IKitchenTicketService
{
    private readonly ConcurrentDictionary<Guid, DataKitchenTicketStatus> _tickets = new();

    /// <inheritdoc />
    public Task<DtoKitchenTicketStatus> GetStatusAsync(Guid ticketId, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        if (!_tickets.TryGetValue(ticketId, out var status))
        {
            throw new KeyNotFoundException($"No kitchen ticket was found for id '{ticketId}'.");
        }

        var dtoStatus = KitchenTicketStatusMapper.ToDtoStatus(status);
        return Task.FromResult(dtoStatus);
    }

    /// <inheritdoc />
    public Task UpdateStatusAsync(Guid ticketId, DtoKitchenTicketStatus newStatus, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var domainStatus = KitchenTicketStatusMapper.ToDomainStatus(newStatus);
        _tickets.AddOrUpdate(ticketId, domainStatus, (_, _) => domainStatus);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task<IReadOnlyCollection<Guid>> GetTicketsByStatusAsync(DtoKitchenTicketStatus status, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var domainStatus = KitchenTicketStatusMapper.ToDomainStatus(status);
        var matchingIds = _tickets
            .Where(pair => pair.Value == domainStatus)
            .Select(pair => pair.Key)
            .ToArray();
        return Task.FromResult<IReadOnlyCollection<Guid>>(matchingIds);
    }
}
