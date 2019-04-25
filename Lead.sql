if db_id('FleitasArts') is null create database FleitasArts;
go
use FleitasArts
go
drop table if exists Ticket
drop table if exists Lead
drop table if exists CustomerAccount
drop table if exists Customer
go
set nocount on;
/*
-- +-----------+
-- | Form Ref: |
-- +-----------+
	rent = HO4
	condo and not rent = HO6
	home and live in = HO3
	home and rent out = DP
	apt can be assumed to HO4
*/
if object_id('Customer') is null
begin
	create table Customer (
 		 [CustomerId]	int identity(1,1)
		,[Name]			nvarchar(256)
		,[Email]		varchar(320)
		constraint pkCustomer primary key clustered ([CustomerId] asc)
	);
end
go
if object_id('CustomerAccount') is null
begin
	create table CustomerAccount (
 		 [CustomerAccountId]	int identity(1,1)
		,[CustomerId]			int foreign key references Customer(CustomerId)
		,[AcctNumEnding]		int
		constraint pkCustomerAccount primary key clustered ([CustomerAccountId] asc)
	);
end
go
if object_id('Lead') is null
begin
	create table Lead (
 		 [LeadId]		int identity(1001,1)
		,[Name]			nvarchar(256)
		,[Email]		varchar(320)
		--,[Phone]		varchar(20)
		,[Address]		nvarchar(256)
		--,[Type]		varchar(25) --house, condo, apartment, townhouse
		--,[Occupancy]	varchar(25) --tenant, owner, seasonal, secondary, vacant.
		--,[Use]		varchar(25) --rent, rent out, live
		,[Status]		bit default(0) -- 0 open / 1 closed
		,[CreatedBy]	nvarchar(128)
		,[CreatedOn]	datetime default getdate()
		,[ModifiedBy]	nvarchar(128) 
		,[ModifiedOn]	datetime 
		constraint pkLeads primary key clustered ([LeadId] asc)
	);
end
go
if object_id('Ticket') is null
begin
	create table Ticket (
 		 [TicketId]			int identity(2001,1)
		,[CustomerId]		int 
		,[AcctNumEnding]	int	
		,[Status]			bit default(0) -- 0 open / 1 closed
		,[LeadId]			int foreign key references Lead(LeadId)
		,[CreatedBy]		nvarchar(128) default suser_name()
		,[CreatedOn]		datetime default getdate()
		,[ModifiedBy]		nvarchar(128) default suser_name()
		,[ModifiedOn]		datetime default getdate()
		constraint pkTicket primary key clustered ([TicketId] asc)
	);
end
go
insert Customer values 
 ('Don',	'dmoney@icloud.com'	)
,('Lou',	'sweetlou@gmail.com')
,('Jackie',	'hr@icloud.com'		)
go
insert CustomerAccount values 
 (1, 9256)
,(2, 7146)
,(3, 6401)
go
insert Lead values
 ('Don', 'dmoney@icloud.com', '501 S Ocean Blvd, Palm Beach, FL 33480', 0, suser_name(), getdate(), null,null) --'561-805-9256', 'condo', 'seasonal', 'rent out', 
,('Tony', 'wakeboard@live.com', '401 E 65th St, Hialeah, FL 33013', 0, suser_name(), getdate(), null,null) --'786-381-4056', 'house', 'owner', 'live', 
,('Jackie', 'hr@icloud.com', '401 E 65th St, Hialeah, FL 33013', 0, suser_name(), getdate(), null,null) 

,('Kim', 'ciokim@icloud.com', '700 Lake Dr, Boca Raton, FL 33432', 0, suser_name(), getdate(), null,null)
,('Fabina',	'fabi@aol.com', '215 SE Spanish Trl, Boca Raton, FL 33432', 0, suser_name(), getdate(), null,null)
,('Christina', 'csosa@live.com', '13 Sunset Key Dr, Key West, FL 33040', 0, suser_name(), getdate(), null,null)
go
insert Ticket values 
 (1, 9256, 0, 1001, suser_name(), getdate(), null, null)
,(3, 6401, 0, 1003, suser_name(), getdate(), null, null)
go
select * from Customer;
select * from CustomerAccount;
select * from Lead;
select * from Ticket;
go
create or alter proc CheckLead (
	@Email	varchar(320) 
)
as
	declare  @CustomerId int, @AcctNumEnd int;

	if object_id('tempdb.dbo.#CheckLead') is not null drop table #CheckLead;
	create table #CheckLead (AcctNumEnd	int);
		
	if @Email is not null
	begin
		select @CustomerId = CustomerId from Customer where Email=@Email;
	
		insert	#CheckLead (AcctNumEnd)
		select	AcctNumEnding
		from	CustomerAccount where CustomerId = @CustomerId;

		select top 1 @AcctNumEnd=AcctNumEnd from #CheckLead;

		if @CustomerId is not null and @AcctNumEnd is not null
		begin try
			select		t.TicketId, t.LeadId
			from		Ticket t
			inner join	#CheckLead cl
				on	cl.AcctNumEnd = t.[AcctNumEnding]
		end try
		begin catch
			select 'Check Failed' as Error;
			throw;
		end catch
	end
go
exec CheckLead @email='dmoney@icloud.com';
exec CheckLead @email='wakeboard@live.com';
exec CheckLead @email='hr@icloud.com';
go
create or alter proc LinkLead (
	 @LeadId	int 
	,@Email		varchar(320)
	,@Name		nvarchar(256)
)
as
	declare  @CustomerId	int 
			,@TicketId		int
			,@date			datetime;

	--select @CustomerId = CustomerId from Customer where Email=@Email;
	select @LeadId = LeadId from Lead where Name=@Name and Email=@Email;

	--if @TicketId is not null and @CustomerId is not null
	begin try
		/*update	Ticket 
		set		CustomerId = @CustomerId, LeadId = @LeadId,
				ModifiedBy = suser_name(), ModifiedOn = getdate()
		where	TicketId = @TicketId*/
		insert Ticket values (
			null, null, 0, @LeadId, suser_name(), getdate(), null, null
		)
	end try
	begin catch
		select 'Link Failed' as Error;
		throw;
	end catch

	select	TicketId, CustomerId, LeadId, Status, CreatedBy, CreatedOn, ModifiedBy 
	from	Ticket 
	where	LeadId = @LeadId
go
exec LinkLead 1002, 'wakeboard@live.com', 'Tony'
go
create or alter proc DeleteLead (
	 @Name		nvarchar(256)
	,@Email		varchar(320)
)
as
	declare  @LeadId	int 
			,@TicketId	int

	select @LeadId = LeadId from Lead where Email=@Email and Name=@Name
	select @TicketId = TicketId from Ticket where LeadId=@LeadId

	if @LeadId is not null
	begin try
		delete	top (1) from Ticket where @LeadId=LeadId
		delete  top (1) from Lead where Email=@Email and Name=@Name
		
		select 'Deleted:' as Msg, @LeadId as LeadId, @TicketId as TicketId
	end try
	begin catch
		select 'Delete Failed' as Error;
		throw;
	end catch
go
exec DeleteLead 'Jackie','hr@icloud.com';
