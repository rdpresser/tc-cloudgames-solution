using System.Text.Json.Serialization;

namespace TC.CloudGames.Functions.Messages
{
    public record EventContext<TEvent>
        where TEvent : class
    {
        [JsonPropertyName("eventData")]
        public TEvent EventData { get; init; } = null!;

        [JsonPropertyName("source")]
        public string? Source { get; init; }

        [JsonPropertyName("eventType")]
        public string EventType { get; init; } = typeof(TEvent).Name;
    }
}
