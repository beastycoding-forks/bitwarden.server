﻿-- Remove ON DELETE for service accounts
IF EXISTS (SELECT name FROM sys.foreign_keys WHERE name = 'FK_ServiceAccount_OrganizationId')
BEGIN
    ALTER TABLE [ServiceAccount] DROP CONSTRAINT [FK_ServiceAccount_OrganizationId];
END

ALTER TABLE [ServiceAccount] ADD CONSTRAINT [FK_ServiceAccount_OrganizationId] FOREIGN KEY ([OrganizationId]) REFERENCES [dbo].[Organization] ([Id]);
GO

IF OBJECT_ID('[dbo].[AccessPolicy]') IS NULL
BEGIN
    CREATE TABLE [AccessPolicy] (
        [Id]                 UNIQUEIDENTIFIER NOT NULL,
        [OrganizationUserId] UNIQUEIDENTIFIER NULL,
        [GroupId]            UNIQUEIDENTIFIER NULL,
        [ServiceAccountId]   UNIQUEIDENTIFIER NULL,
        [ProjectId]          UNIQUEIDENTIFIER NULL,
        [SecretId]           UNIQUEIDENTIFIER NULL,
        [Read]               BIT NOT NULL,
        [Write]              BIT NOT NULL,
        [CreationDate]       DATETIME2 NOT NULL,
        [RevisionDate]       DATETIME2 NOT NULL,
        CONSTRAINT [PK_AccessPolicy] PRIMARY KEY CLUSTERED ([Id]),
        CONSTRAINT [FK_AccessPolicy_Group_GroupId] FOREIGN KEY ([GroupId]) REFERENCES [Group] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_AccessPolicy_OrganizationUser_OrganizationUserId] FOREIGN KEY ([OrganizationUserId]) REFERENCES [OrganizationUser] ([Id]),
        CONSTRAINT [FK_AccessPolicy_Project_ProjectId] FOREIGN KEY ([ProjectId]) REFERENCES [Project] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_AccessPolicy_Secret_SecretId] FOREIGN KEY ([SecretId]) REFERENCES [Secret] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_AccessPolicy_ServiceAccount_ServiceAccountId] FOREIGN KEY ([ServiceAccountId]) REFERENCES [ServiceAccount] ([Id]) ON DELETE CASCADE
    );

    CREATE NONCLUSTERED INDEX [IX_AccessPolicy_GroupId] ON [AccessPolicy] ([GroupId]);

    CREATE NONCLUSTERED INDEX [IX_AccessPolicy_OrganizationUserId] ON [AccessPolicy] ([OrganizationUserId]);

    CREATE NONCLUSTERED INDEX [IX_AccessPolicy_ProjectId] ON [AccessPolicy] ([ProjectId]);

    CREATE NONCLUSTERED INDEX [IX_AccessPolicy_SecretId] ON [AccessPolicy] ([SecretId]);

    CREATE NONCLUSTERED INDEX [IX_AccessPolicy_ServiceAccountId] ON [AccessPolicy] ([ServiceAccountId]);
END
GO

CREATE OR ALTER PROCEDURE [dbo].[OrganizationUser_DeleteById]
    @Id UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON

    EXEC [dbo].[User_BumpAccountRevisionDateByOrganizationUserId] @Id

    DECLARE @OrganizationId UNIQUEIDENTIFIER
    DECLARE @UserId UNIQUEIDENTIFIER

    SELECT
        @OrganizationId = [OrganizationId],
        @UserId = [UserId]
    FROM
        [dbo].[OrganizationUser]
    WHERE
        [Id] = @Id

    IF @OrganizationId IS NOT NULL AND @UserId IS NOT NULL
    BEGIN
        EXEC [dbo].[SsoUser_Delete] @UserId, @OrganizationId
    END

    DELETE
    FROM
        [dbo].[CollectionUser]
    WHERE
        [OrganizationUserId] = @Id

    DELETE
    FROM
        [dbo].[GroupUser]
    WHERE
        [OrganizationUserId] = @Id

   DELETE
   FROM
       [dbo].[AccessPolicy]
   WHERE
       [OrganizationUserId] = @Id

    EXEC [dbo].[OrganizationSponsorship_OrganizationUserDeleted] @Id

    DELETE
    FROM
        [dbo].[OrganizationUser]
    WHERE
        [Id] = @Id
END
