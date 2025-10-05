using System.Text.Json.Serialization;

namespace TC.CloudGames.Functions.Messages;

public class UserPurchaseMessage
{
    [JsonPropertyName("userId")]
    public Guid UserId { get; set; }
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;
    [JsonPropertyName("gameName")]
    public string GameName { get; set; } = string.Empty;
    [JsonPropertyName("amount")]
    public decimal Amount { get; set; }
    [JsonPropertyName("occurredOn")]
    public DateTimeOffset OccurredOn { get; set; }
}

