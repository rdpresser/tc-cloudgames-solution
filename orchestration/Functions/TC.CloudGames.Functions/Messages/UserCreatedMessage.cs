namespace TC.CloudGames.Functions.Messages
{
    public class UserCreatedMessage
    {
        public Guid UserId { get; set; }
        public string Name { get; set; }
        public string Email { get; set; }
    }
}
