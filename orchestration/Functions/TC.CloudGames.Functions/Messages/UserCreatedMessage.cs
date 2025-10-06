using System.Text.Json.Serialization;

namespace TC.CloudGames.Functions.Messages
{
    public class UserCreatedMessage
    {
        [JsonPropertyName("aggregateId")]
        public Guid UserId { get; set; }

        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [JsonPropertyName("username")]
        public string Username { get; set; } = string.Empty;
    }
}
