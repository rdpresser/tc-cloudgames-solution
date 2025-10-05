namespace TC.CloudGames.Functions.Abstractions
{
    public interface ISendGridService
    {
        Task SendWelcomeEmailAsync(UserCreatedMessage userCreated);
        Task SendPurchaseEmailAsync(UserPurchaseMessage purchase);
    }
}
