-- Copyright 2016-2019, Firaxis Games
-- See global EndGameMenu_ include at bottom of file!

include("InstanceManager")
include("EndGameReplayLogic")
include("ChatLogic");
include("TeamSupport");
include("PopupDialog");
print("Custom EndGameMenu for MPH")

-- ===========================================================================
-- CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID :string = "EndGameMenu";
local MAX_BUTTON_SIZE = 160;	-- also global
local bWasInHistoricMoments = false;
local m_concede = false
local m_spec = false

-- ===========================================================================
-- Globals
-- ===========================================================================
g_GraphVerticalMarkers = {
	Controls.VerticalLabel1,
	Controls.VerticalLabel2,
	Controls.VerticalLabel3,
	Controls.VerticalLabel4,
	Controls.VerticalLabel5
};

g_GraphHorizontalMarkers = {
	Controls.HorizontalLabel1,
	Controls.HorizontalLabel2,
	Controls.HorizontalLabel3,
	Controls.HorizontalLabel4,
	Controls.HorizontalLabel5
};

-- Custom popup setup
g_kPopupDialog = PopupDialog:new( "EndGameMenu" );

g_HasPlayerPortrait = false;			-- Whether or not a player portrait has been set.
g_HideLeaderPortrait = false;	-- Whether or not there is enough space to show the portrait

Styles = {
	["GENERIC_DEFEAT"] ={
		RibbonIcon = "ICON_DEFEAT_GENERIC",
		Ribbon = "EndGame_Ribbon_Defeat",
		RibbonTile = "EndGame_RibbonTile_Defeat",
		Background = "EndGame_BG_Defeat",
		Movie = "Defeat.bk2",
		SndStart = "Play_Cinematic_Endgame_Defeat",
		SndStop = "Stop_Cinematic_Endgame_Defeat",
	},
	["GENERIC_VICTORY"] = {
		RibbonIcon = "ICON_VICTORY_SCORE",
		Ribbon = "EndGame_Ribbon_Time",
		RibbonTile = "EndGame_RibbonTile_Time",
		Background = "EndGame_BG_Time",
		Color = "COLOR_VICTORY_DEFAULT",
	},
	["DEFEAT_DEFAULT"] ={
		RibbonIcon = "ICON_DEFEAT_GENERIC",
		Ribbon = "EndGame_Ribbon_Defeat",
		RibbonTile = "EndGame_RibbonTile_Defeat",
		Background = "EndGame_BG_Defeat",
		Movie = "Defeat.bk2",
		SndStart = "Play_Cinematic_Endgame_Defeat",
		SndStop = "Stop_Cinematic_Endgame_Defeat",
	},
	["DEFEAT_CONCEDE"] ={
		RibbonIcon = "ICON_DEFEAT_GENERIC",
		Ribbon = "EndGame_Ribbon_Defeat",
		RibbonTile = "EndGame_RibbonTile_Defeat",
		Background = "EndGame_BG_Defeat",
		Movie = "Defeat.bk2",
		SndStart = "Play_Cinematic_Endgame_Defeat",
		SndStop = "Stop_Cinematic_Endgame_Defeat",
	},
	["DEFEAT_TIME"] ={
		RibbonIcon = "ICON_DEFEAT_GENERIC",
		Ribbon = "EndGame_Ribbon_Defeat",
		RibbonTile = "EndGame_RibbonTile_Defeat",
		Background = "EndGame_BG_Defeat",
		Movie = "Defeat.bk2",
		SndStart = "Play_Cinematic_Endgame_Defeat",
		SndStop = "Stop_Cinematic_Endgame_Defeat",
	},
	["VICTORY_SCORE"] = {
		RibbonIcon = "ICON_VICTORY_SCORE",
		Ribbon = "EndGame_Ribbon_Time",
		RibbonTile = "EndGame_RibbonTile_Time",
		Background = "EndGame_BG_Time",
		Movie = "Time.bk2",
		SndStart = "Play_Cinematic_Endgame_Time",
		SndStop = "Stop_Cinematic_Endgame_Time",
		Color = "COLOR_VICTORY_SCORE",
	},
	["VICTORY_DEFAULT"] = {
		RibbonIcon = "ICON_VICTORY_DEFAULT",
		Ribbon = "EndGame_Ribbon_Domination",
		RibbonTile = "EndGame_RibbonTile_Domination",
		Background = "EndGame_BG_Domination",
		Movie = "Domination.bk2",
		SndStart = "Play_Cinematic_Endgame_Domination",
		SndStop = "Stop_Cinematic_Endgame_Domination",
		Color = "COLOR_VICTORY_DEFAULT",
	},
	["VICTORY_CONCEDE"] = {
		RibbonIcon = "ICON_VICTORY_DEFAULT",
		Ribbon = "EndGame_Ribbon_Domination",
		RibbonTile = "EndGame_RibbonTile_Domination",
		Background = "EndGame_BG_Domination",
		Movie = "Domination.bk2",
		SndStart = "Play_Cinematic_Endgame_Domination",
		SndStop = "Stop_Cinematic_Endgame_Domination",
		Color = "COLOR_VICTORY_DEFAULT",
	},
	["VICTORY_CONQUEST"] = {
		RibbonIcon = "ICON_VICTORY_CONQUEST",
		Ribbon = "EndGame_Ribbon_Domination",
		RibbonTile = "EndGame_RibbonTile_Domination",
		Background = "EndGame_BG_Domination",
		Movie = "Domination.bk2",
		SndStart = "Play_Cinematic_Endgame_Domination",
		SndStop = "Stop_Cinematic_Endgame_Domination",
		Color = "COLOR_VICTORY_DOMINATION",
	},
	["VICTORY_CULTURE"] = {
		RibbonIcon = "ICON_VICTORY_CULTURE",
		Ribbon = "EndGame_Ribbon_Culture",
		RibbonTile = "EndGame_RibbonTile_Culture",
		Background = "EndGame_BG_Culture",
		Movie = "Culture.bk2",
		SndStart = "Play_Cinematic_Endgame_Culture",
		SndStop = "Stop_Cinematic_Endgame_Culture",
		Color = "COLOR_VICTORY_CULTURE",
	},
	["VICTORY_RELIGIOUS"] = {
		RibbonIcon = "ICON_VICTORY_RELIGIOUS",
		Ribbon = "EndGame_Ribbon_Religion",
		RibbonTile = "EndGame_RibbonTile_Religion",
		Background = "EndGame_BG_Religion",
		Movie = "Religion.bk2",
		SndStart = "Play_Cinematic_Endgame_Religion",
		SndStop = "Stop_Cinematic_Endgame_Religion",
		Color = "COLOR_VICTORY_RELIGION",
	},
	["VICTORY_TECHNOLOGY"] = {
		RibbonIcon = "ICON_VICTORY_TECHNOLOGY",
		Ribbon = "EndGame_Ribbon_Science",
		RibbonTile = "EndGame_RibbonTile_Science",
		Background = "EndGame_BG_Science",
		Movie = "Science.bk2",
		SndStart = "Play_Cinematic_Endgame_Science",
		SndStop = "Stop_Cinematic_Endgame_Science",
		Color = "COLOR_VICTORY_SCIENCE",
	},
	
	-- XP2
	["VICTORY_DIPLOMATIC"] = {
		RibbonIcon = "ICON_VICTORY_DIPLOMATIC",
		Ribbon = "EndGame_Ribbon_Diplomatic",
		RibbonTile = "EndGame_RibbonTile_Diplomatic",
		Background = "EndGame_BG_Time",
		Movie = "XP2Victory_Diplomatic.bk2",
		SndStart = "Play_Cinematic_Endgame_Diplomatic",
		SndStop = "Stop_Cinematic_Endgame_Diplomatic",
		Color = "COLOR_VICTORY_DIPLOMATIC",
	},
	-- Kluuudge
	["VICTORY_ALEXANDER"] = {
		RibbonIcon = "ICON_VICTORY_DEFAULT",
		Ribbon = "EndGame_Ribbon_Domination",
		RibbonTile = "EndGame_RibbonTile_Domination",
		Background = "EndGame_BG_Domination",
		Movie = "Domination.bk2",
		SndStart = "Play_Cinematic_Endgame_Domination",
		SndStop = "Stop_Cinematic_Endgame_Domination",
		Color = "COLOR_VICTORY_DEFAULT",
	},
};



-- ===========================================================================
--	MEMBERS
-- ===========================================================================

local m_rankIM = InstanceManager:new( "RankEntry", "Root", Controls.RankingStack );

local m_movie;				-- The movie which has been set.
local m_soundtrackStart;    -- Wwise start event for the movie's audio
local m_soundtrackStop;     -- Wwise stop event for the movie's audio
local m_savedMusicVol;      -- Saved music volume around movie play

-- Chat Panel Data
local m_playerTarget		:table = { targetType = ChatTargetTypes.CHATTARGET_ALL, targetID = GetNoPlayerTargetID() };
local m_playerTargetEntries :table = {};
local m_ChatInstances		:table = {};

local PlayerConnectedChatStr	:string = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED_CHAT" );
local PlayerDisconnectedChatStr :string = Locale.Lookup( "LOC_MP_PLAYER_DISCONNECTED_CHAT" );
local PlayerHostMigratedChatStr :string = Locale.Lookup( "LOC_MP_PLAYER_HOST_MIGRATED_CHAT" );
local PlayerKickedChatStr		:string = Locale.Lookup( "LOC_MP_PLAYER_KICKED_CHAT" );

local m_isFadeOutGame	:boolean = false;
local m_MovieWasPlayed	:boolean = false;
local m_teamVictory		:boolean = false;
local m_waitingForShow	:boolean = false;					-- Has the screen queued itself to be displayed? Returns to false in OnShow. 
															-- Used to determine if the screen is waiting to be displayed when multiple victory/defeat events come while the screen is still waiting to be displayed.
local m_viewerPlayer	:number = PlayerTypes.NO_PLAYER;	-- The screen is being generated from the perspective of this player.  This might not be the same as the local player in hotseat.
local m_savedData		:table = nil;						-- Used for hotreloading



----------------------------------------------------------------
-- Utility function that lets me pass an icon string or
-- an array of icons to attempt to use.
-- Upon success, show the control.  Failure, hide the control.  
----------------------------------------------------------------  
function SetIcon(control, icon) 
	control:SetHide(false);

	if(icon == nil) then
		control:SetHide(true);
		return;
	else
		if(type(icon) == "string") then
			if(control:SetIcon(icon)) then
				return;
			end

		elseif(type(icon) == "table") then
			for i,v in ipairs(icon) do
				if(control:SetIcon(v)) then
					return;
				end
			end	
		end
		control:SetHide(true);
	end
end

----------------------------------------------------------------  
----------------------------------------------------------------  
function PopulateRankingResults()
	m_rankIM:ResetInstances();

	local player = Players[Game.GetLocalPlayer()];
	local score = player:GetScore();
	
	local playerAdded = false;
	local count = 1;
	for row in GameInfo.HistoricRankings() do
		local instance = m_rankIM:GetInstance();
	
		instance.Number:LocalizeAndSetText("LOC_UI_ENDGAME_NUMBERING_FORMAT", count);
		instance.LeaderName:LocalizeAndSetText(row.HistoricLeader);
		
		if(score >= row.Score and not playerAdded)then
			instance.LeaderScore:SetText(Locale.ToNumber(score));
			instance.LeaderQuote:LocalizeAndSetText(row.Quote);
			instance.LeaderQuote:SetHide(false);
			Controls.RankingTitle:LocalizeAndSetText("LOC_UI_ENDGAME_RANKING_STATEMENT", row.HistoricLeader);
			playerAdded = true;
		else
			instance.LeaderScore:SetText(Locale.ToNumber(row.Score));
			instance.LeaderQuote:SetHide(true);
		end

		count = count + 1;
	end

	Controls.RankingScrollPanel:SetScrollValue(0);
	
	Controls.RankingStack:CalculateSize();
	Controls.RankingStack:ReprocessAnchoring();
	Controls.RankingScrollPanel:CalculateInternalSize();
end

function UpdateButtonStates(data:table)
	print("UpdateButtonStates")
	-- Display a continue button if there are other players left in the game
	local player = Players[Game.GetLocalPlayer()];
	if player ~= nil then
		if PlayerConfigurations[Game.GetLocalPlayer()]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
			m_spec = true
		end
	end

	-- In hotseat there is a Next Player button that allows the game to continue in the case of an individual player's defeat.
	local nextPlayer = false;
	if(GameConfiguration.IsHotseat()
		and not data.NoMorePlayers					-- We are not in a state where there will be no more players to continue to.
		and data.WinningTeamID == nil ) then		-- There is no victory.  In the case of a victory we only show the end game screen however is the active player at the time.
													-- The game might be One More Turned but that is handled by canExtendGame.
		local humans = GameConfiguration.GetHumanPlayerIDs();
		for i,v in ipairs(humans) do
			local human = Players[v];
			if(human and human:IsAlive()) then
				nextPlayer = true;
				break;
			end
		end
	end

	local noExtendedGame = GameConfiguration.GetValue("NO_EXTENDED_GAME");
	-- Was One More Turn ever allowed for the current game?
	local everAllowExtended = (noExtendedGame == nil or (noExtendedGame ~= 1 and noExtendedGame ~= true))
							and not GameConfiguration.IsPlayByCloud();			
	-- Is One More Turn allowed for the local player now?							
	local canExtendGame = everAllowExtended;
	
	if data ~= nil and data.OneMoreTurn ~= nil then
		canExtendGame = data.OneMoreTurn;
	end
	
	canExtendGame = canExtendGame and player and player:IsAlive() and Game.GetLocalObserver() ~= PlayerTypes.OBSERVER;
	
	-- Don't show next player button if Just One More Turn will be shown as the functionality is the same.
	nextPlayer = nextPlayer and not canExtendGame;

	-- Always show the main menu button.
	Controls.MainMenuButton:SetHide(false);
	-- Concede can continue playing
	if m_concede == true or m_spec == true then
		canExtendGame = true
	end
	-- Enable just one more turn if we can extend the game.
	-- Show the just one more turn button if we're not showing the next player button.	
	-- Hide the one more turn button if it was never allowed for this game.
	Controls.BackButton:SetDisabled(not canExtendGame);
	Controls.BackButton:SetHide(nextPlayer or not everAllowExtended);

	-- Show the next player button only if in a hot-seat match and just one more turn is disabled.
	Controls.NextPlayerButton:SetHide(not nextPlayer);
	
	Controls.ButtonStack:CalculateSize();
end

----------------------------------------------------------------
----------------------------------------------------------------
function OnNextPlayer()
	-- If the end game screen was for the local player and they are turn active, we need to send end turn so the game will advance.
	-- Otherwise, the screen will simply pop and the current turn active player can keep playing.
	local localPlayerID :number = Game.GetLocalPlayer();
	local pLocalPlayer :table = Players[localPlayerID];
	if(m_viewerPlayer ~= PlayerTypes.NO_PLAYER 
		and m_viewerPlayer == localPlayerID 
		and pLocalPlayer:IsTurnActive() == true) then
		UI.RequestAction(ActionTypes.ACTION_ENDTURN);
	end
	--Reset waiting for show so next player to be defeated/win can view the end game screen
	m_waitingForShow = false;																												  

	Close();
end

-- ===========================================================================
function Close()

	ReplayShutdown();
	m_rankIM:ResetInstances();	-- Unload instances.	
	Controls.Movie:Close();		-- Unload movie
	
	-- Unload large textures.
	Controls.Background:UnloadTexture();
	Controls.PlayerPortrait:UnloadTexture();

	UIManager:DequeuePopup( ContextPtr );
	UI.UnloadSoundBankGroup(5);	
	UI.ReleasePauseEvent();		-- Release any event we might have been holding on to.	

	local isHiding:boolean = true;
	HandlePauseGame( isHiding );	
end

-- ===========================================================================
function OnMainMenu()    
	Controls.Movie:Close();		-- Unload movie
	UI.UnloadSoundBankGroup(5);	
	UI.ReleasePauseEvent();		-- Release any event we might have been holding on to.	

	Events.ExitToMainMenu();	
end

-- ===========================================================================
function OnBack()    
	Close();	
	LuaEvents.EndGameMenu_OneMoreTurn();	
end

-- ===========================================================================
--	UI Callback
--	Tab button pressed to look at the information panel.
-- ===========================================================================
function OnInfoTab()
    Controls.InfoPanel:SetHide(false);
	Controls.RankingPanel:SetHide(true);
    Controls.GraphPanel:SetHide(true);
	Controls.ChatPanel:SetHide(true);
	Controls.PlayerPortrait:SetHide(g_HideLeaderPortrait);

	Controls.InfoButtonSelected:SetHide(false);
	Controls.RankingButtonSelected:SetHide(true);
	Controls.ReplayButtonSelected:SetHide(true);
	Controls.ChatButtonSelected:SetHide(true);
end

-- ===========================================================================
--	UI Callback
--	Tab button pressed to look at the rankings.
-- ===========================================================================
function OnRankingTab()
    Controls.InfoPanel:SetHide(true);
	Controls.RankingPanel:SetHide(false);
    Controls.GraphPanel:SetHide(true);
	Controls.ChatPanel:SetHide(true);
	Controls.PlayerPortrait:SetHide(g_HideLeaderPortrait);

	Controls.InfoButtonSelected:SetHide(true);
	Controls.RankingButtonSelected:SetHide(false);
	Controls.ReplayButtonSelected:SetHide(true);
	Controls.ChatButtonSelected:SetHide(true);

	PopulateRankingResults();
end

-- ===========================================================================
--	UI Callback
--	Tab button pressed to look at the game reply.
-- ===========================================================================
function OnReplayTab()
    Controls.InfoPanel:SetHide(true);
	Controls.RankingPanel:SetHide(true);
    Controls.GraphPanel:SetHide(false);
	Controls.ChatPanel:SetHide(true);
	Controls.PlayerPortrait:SetHide(true);

	Controls.InfoButtonSelected:SetHide(true);
	Controls.RankingButtonSelected:SetHide(true);
	Controls.ReplayButtonSelected:SetHide(false);
	Controls.ChatButtonSelected:SetHide(true);

	ReplayInitialize();
end

-- ===========================================================================
--	UI Callback
--	Tab button pressed to bring up the chat screen.
-- ===========================================================================
function OnChatTab()
    Controls.InfoPanel:SetHide(true);
	Controls.RankingPanel:SetHide(true);
    Controls.GraphPanel:SetHide(true);
	Controls.ChatPanel:SetHide(false);
	Controls.PlayerPortrait:SetHide(true);

	Controls.InfoButtonSelected:SetHide(true);
	Controls.RankingButtonSelected:SetHide(true);
	Controls.ReplayButtonSelected:SetHide(true);
	Controls.ChatButtonSelected:SetHide(false);
end

-- ===========================================================================
function OnReplayMovie()
	if(bWasInHistoricMoments) then 
		return 
	end
	
	if(m_movie) then
		if Controls.Movie:SetMovie(m_movie) then
    		Controls.MovieFill:SetHide(false);
    		Controls.Movie:Play();
            UI.StopInGameMusic();
            UI.PlaySound(m_soundtrackStart);
            m_savedMusicVol = Options.GetAudioOption("Sound", "Music Volume"); 
            Options.SetAudioOption("Sound", "Music Volume", 0, 0);
            m_MovieWasPlayed = true;
        end
	end

	-- If in Network MP, release the pause event, so our local machine continues processing
	if (GameConfiguration.IsNetworkMultiplayer()) then
		UI.ReleasePauseEvent();
	end
end

-- ===========================================================================
function OnMovieExitOrFinished()
	Controls.Movie:Close();
	Controls.MovieFill:SetHide(true);
    if (m_MovieWasPlayed) then
        UI.PlaySound(m_soundtrackStop);
        Options.SetAudioOption("Sound", "Music Volume", m_savedMusicVol, 0);
        UI.SkipSong();
        m_MovieWasPlayed = false;
    end

	-- If in Network or PlayByCloud MP, release the pause event, so our local machine continues processing
	if (GameConfiguration.IsNetworkMultiplayer() or GameConfiguration.IsPlayByCloud()) then
		UI.ReleasePauseEvent();
	end
end

-- ===========================================================================
function OnHistoricMoments()
	bWasInHistoricMoments = true;
	LuaEvents.EndGameMenu_OpenHistoricMoments(Controls.HistoricMoments);
end

-- ===========================================================================
function OnExportHistoricMoments()
	 local path, filename = Game.GetHistoryManager():WritePrideMomentInfo();

	 if (not g_kPopupDialog:IsOpen()) then
		g_kPopupDialog:AddTitle(Locale.ToUpper("LOC_END_GAME_MENU_EXPORT_HISTORIAN_BUTTON"));
		g_kPopupDialog:AddText(path);
		g_kPopupDialog:AddButton( Locale.Lookup("LOC_OK_BUTTON"), nil);
		g_kPopupDialog:Open();
	end
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnFadeAbort()
	local isCallDelegate:boolean = true;
	if(Controls.BackgroundFade:GetProgress() < 1)then
		Controls.BackgroundFade:SetToEnd( isCallDelegate );
	end
	
end

-- ===========================================================================
function OnInputHandler( kInput:table )
	local msg :number = kInput:GetMessageType();
	if msg == KeyEvents.KeyUp then
		local key :number = kInput:GetKey();
		
		-- If ESC, have it act based on what is happening with the screen.
		if (key == Keys.VK_ESCAPE) then
			if m_isFadeOutGame then
				OnFadeAbort();
			elseif Controls.MovieFill:IsVisible() then
				OnMovieExitOrFinished();
			end			
			return true;	-- Always trap the escape key here.
		end
		
		return true;	-- Swallow ALL the keys so panning with arrows cannot occur nor action keys!
	end

	if (msg == KeyEvents.KeyDown) then
		return true;	-- Swallow ALL the keys so panning with arrows cannot occur nor action keys!
	end

	return false;
end

-- ===========================================================================
--	UI Callback
--	After fading in from a game ending.
-- ===========================================================================
function ShowComplete()
	print("ShowComplete()");
	m_isFadeOutGame = false;
	Controls.MainBacking:SetHide( false );	
	Controls.AllContentPanels:SetHide( false );
	Controls.AllContentPanels:SetToBeginning();
	Controls.AllContentPanels:Play();	
	if g_HideLeaderPortrait == false then
		Controls.PortraitFade:SetToBeginning();
		Controls.PortraitFade:Play();
	end

	Controls.ButtonStack:SetHide( false );	
	OnInfoTab();					-- Always start with the info panel.	
	OnReplayMovie();				-- Noop if no movie is set.
end


-- ===========================================================================
function OnShow()
	print("Showing EndGame Menu of MPH");
	-- Under really broken circumstances we can get here with the menu music/Dawn of Man VO still playing.  Stop it.
	UI.PlaySound("STOP_SPEECH_DAWNOFMAN");
	UI.StartStopMenuMusic(false);																												 									  							  

	m_waitingForShow = false;

	LuaEvents.EndGameMenu_Shown();	-- Add ingame bulk hide counter
	Resize();						-- Verify we're scaled properly.

	-- Setup Chat Player Target Pulldown.
	PopulateTargetPull(Controls.ChatPull, Controls.ChatEntry, Controls.ChatIcon, m_playerTargetEntries, m_playerTarget, false, OnChatPulldownChanged);

	-- TODO: Better place for this to happen so it doesn't get called on every show (every queue popup)
	local isHiding:boolean = false;
	HandlePauseGame( isHiding );

	if m_isFadeOutGame then
		print("OnShow m_isFadeOutGame = true ");
		-- Hide anything that shouldn't be shown overtop of the win/lose screen
		Controls.MainBacking:SetHide( true );
		Controls.AllContentPanels:SetHide( true );
		Controls.ButtonStack:SetHide( true);
		Controls.MovieFill:SetHide( true );
		Controls.PlayerPortrait:SetHide( true );

		-- Start fading
		Controls.BackgroundFade:RegisterEndCallback( ShowComplete );
		Controls.BackgroundFade:SetToBeginning();
		Controls.BackgroundFade:Play();
	else
		OnInfoTab();					-- Always start with the info panel.	
		OnReplayMovie();				-- Noop if no movie is set.
	end
end

-- ===========================================================================
function OnHide()
	print("Hiding EndGame Menu");
	LuaEvents.EndGameMenu_Closed();		-- Remove ingame bulk (un)hide counter.
end

-- ===========================================================================
-- When should the End Game screen pause the game?
-- Network multiplayer games need to pause the game in specific situations so the game does not progress while the local player looks at this screen.
-- NOTE: We use the gameplay pausing instead of an UI pause event because UI pause events lock gameplay event playback in a unmultiplayer friendly way.
function ShouldPauseGame()
	if(not GameConfiguration.IsNetworkMultiplayer() ) then
		return false;
	end
	
	-- Only pause if there has been a game victory.  We do not pause the game for personal defeats because gameplay should continue for the non-defeated players.
	if(m_teamVictory == false) then
		return false;
	end
	
	return true;	
end

-- ===========================================================================
function HandlePauseGame( bIsHide : boolean )
	if(ShouldPauseGame()) then
		local localPlayerID = Network.GetLocalPlayerID();
		local localPlayerConfig = PlayerConfigurations[localPlayerID];
		if(localPlayerConfig) then
			localPlayerConfig:SetWantsPause(not bIsHide);
			Network.BroadcastPlayerInfo();
		end
	end
end
     
 -- ===========================================================================
function Resize()
	local screenX, screenY = UIManager:GetScreenSizeVal();

	g_HideLeaderPortrait = screenX < 1280;

	Controls.Background:Resize(screenX,screenY);
	Controls.RankingStack:CalculateSize();
	Controls.RankingStack:ReprocessAnchoring();
	Controls.RankingScrollPanel:CalculateInternalSize();

	local portraitOffsetY = math.min(0, screenY-1024);
	Controls.PlayerPortrait:SetOffsetVal(-420, portraitOffsetY);

	-- Show/Hide the ranking button only if there are historic rankings.
	local historicRankingsCount = #GameInfo.HistoricRankings;
	Controls.RankingButtonRoot:SetShow(historicRankingsCount > 0);

	-- Show/Hide the chat panel button
	Controls.ChatButtonRoot:SetShow(GameConfiguration.IsNetworkMultiplayer() and UI.HasFeature("Chat")); 

end

function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if (type == SystemUpdateUI.ScreenResize) then
    Resize();
  end
end

----------------------------------------------------------------
function ViewWinnerPanel(data:table)
	print("ViewWinnerPanel")
	if data.WinnerName ~= "" then
		Controls.VictoryPanel:SetHide(false);

		-- Update pennant
		SetIcon(Controls.VictoryIcon, data.VictoryTypeIcon);
		SetIcon(Controls.VictoryCivIcon, data.WinnerIcon);
		Controls.VictoryCivIconBacking:SetColor(data.WinnerBackColor);
		Controls.VictoryCivIcon:SetColor(data.WinnerFrontColor);
		Controls.VictoryPennant:SetColor(UI.GetColorValue(data.VictoryTypeColor));

		-- Update victory type name and player/team name
		Controls.VictoryTypeName:SetText(Locale.ToUpper(data.VictoryTypeHeader));
		Controls.VictoryPlayerName:SetText(Locale.Lookup(data.WinnerName));

		if data.VictoryBlurb ~= "" then
			Controls.VictoryBlurb:SetHide(false);
			Controls.VictoryBlurbDivider:SetHide(false);
			Controls.VictoryBlurb:SetText(data.VictoryBlurb);
		else
			Controls.VictoryBlurb:SetHide(true);
			Controls.VictoryBlurbDivider:SetHide(true);
		end

		-- Show local player indicator if local player
		if data.IsWinnerLocalPlayer then
			Controls.LocalPlayerRim:SetHide(false);
			Controls.LocalPlayerArrow:SetHide(false);
		else
			Controls.LocalPlayerRim:SetHide(true);
			Controls.LocalPlayerArrow:SetHide(true);
		end

		Controls.VictoryPanel:DoAutoSize();
	else
		Controls.VictoryPanel:SetHide(true);
	end
end

----------------------------------------------------------------
function ViewDefeatedPanel(data:table)
	print("ViewDefeatedPanel")
	if data.DefeatedName ~= "" then
		print("Veiw Defeated Player = Yes")
		Controls.DefeatedPanel:SetHide(false);
		Controls.DefeatedTypeName:SetText(Locale.ToUpper("LOC_DEFEAT_DEFAULT_NAME"));
		Controls.DefeatedPlayerName:SetText(data.DefeatedName);
		SetIcon(Controls.DefeatedCivIcon, data.DefeatedIcon);
		Controls.DefeatedCivIconBacking:SetColor(data.DefeatedBackColor);
		Controls.DefeatedCivIcon:SetColor(data.DefeatedFrontColor);
		Controls.DefeatedCivIconBacking:ReprocessAnchoring();
	else
		Controls.DefeatedPanel:SetHide(true);
	end
end

----------------------------------------------------------------
-- The primary method for updating the UI.
----------------------------------------------------------------
function View(data:table)
	
	m_savedData = data;		-- Only used for hotreload testing

	ViewWinnerPanel(data);
	ViewDefeatedPanel(data);
	
	local localPlayerID:number = Game.GetLocalPlayer();
	if PlayerConfigurations[localPlayerID] ~= nil then
		if PlayerConfigurations[localPlayerID] == "LEADER_SPECTATOR" then
			
		end
	end

	-- Update background
	Controls.Background:SetTexture(data.RibbonStyle.Background);

	-- Update ribbon
	SetIcon(Controls.RibbonIcon, data.RibbonIcon);
	Controls.RibbonLabel:SetText(Locale.ToUpper(Locale.Lookup(data.RibbonText)));
	Controls.Ribbon:SetTexture(data.RibbonStyle.Ribbon);
	Controls.RibbonTile:SetTexture(data.RibbonStyle.RibbonTile);
	Controls.RibbonArea:SetToBeginning();
	Controls.RibbonArea:Play();

	-- Update player portrait
	if(data.PlayerPortrait) then
		g_HasPlayerPortrait = true;
		Controls.PlayerPortrait:SetTexture(data.PlayerPortrait);
		Controls.PlayerPortrait:SetHide(false);
	else
		g_HasPlayerPortrait = false;
		Controls.PlayerPortrait:UnloadTexture();
		Controls.PlayerPortrait:SetHide(true);
	end

	Resize();

	if(g_HideLeaderPortrait) then
		Controls.PlayerPortrait:SetHide(true);
		Controls.PlayerPortrait:UnloadTexture();
	end

	m_viewerPlayer = data.viewerPlayer;

	-- If a fadeout time is specified for this victory type, use that.
	if data.RibbonStyle.FadeOutTime then
		Controls.BackgroundFade:SetSpeed( 1/data.RibbonStyle.FadeOutTime );
	end

	---- Movie begins play-back when UI is shown.
	local tMovie = type(data.RibbonStyle.Movie);
	if(tMovie == "string") then
		m_movie = data.RibbonStyle.Movie;
	elseif(tMovie == "function") then
		m_movie = data.RibbonStyle.Movie();
	end

	local tSndStart = type(data.RibbonStyle.SndStart);
	if(tSndStart == "string") then
	    m_soundtrackStart = data.RibbonStyle.SndStart;
	elseif(tSndStart == "function") then
	    m_soundtrackStart = data.RibbonStyle.SndStart();
	end

	local tSndStop = type(data.RibbonStyle.SndStop);
	if(tSndStop == "string") then
	    m_soundtrackStop = data.RibbonStyle.SndStop;
	elseif(tSndStop == "function") then
	    m_soundtrackStop = data.RibbonStyle.SndStop();
	end
	
    if m_movie ~= nil then
        UI.LoadSoundBankGroup(5);   -- BANKS_FMV, must teach Lua these constants
    end

	Controls.ReplayMovieButton:SetHide(m_movie == nil);
	Controls.MovieFill:SetHide(true);
	Controls.Movie:Close();

	if(ContextPtr:IsHidden()) then		
		UIManager:QueuePopup( ContextPtr, PopupPriority.EndGameMenu );
		m_waitingForShow = true;
	end	

	UpdateButtonStates(data);
end

----------------------------------------------------------------
function DefaultData()
	local data:table = {};
		
	data.PlayerPortrait = "";
	data.viewerPlayer = PlayerTypes.NO_PLAYERS;

	data.RibbonText = "WinOrLose";
	data.RibbonIcon = "ICON_VICTORY_GENERIC";
	data.RibbonStyle = {
		Background = "",
		Ribbon = "",
		RibbonTile = "",
		Movie = "",
		SndStart = "",
		SndStop = ""
	};

	data.IsWinnerLocalPlayer = false;
	data.WinnerName = "";
	data.WinnerIcon = "";
	data.WinnerBackColor = nil;
	data.WinnerFrontColor = nil;

	data.VictoryTypeHeader = "";
	data.VictoryTypeIcon = "";
	data.VictoryTypeColor = nil;
	data.VictoryBlurb = "";

	data.DefeatedName = "";
	data.DefeatedIcon = "";
	data.DefeatedBackColor = nil;
	data.DefeatedFrontColor = nil;

	return data;
end

----------------------------------------------------------------
function PlayerDefeatedData(playerID:number, defeatType:string)
	print("PlayerDefeatedData",playerID,defeatType)
	local data:table = DefaultData();

	data.viewerPlayer = playerID;

	-- Gather player portrait data
	local pPlayerConfig = PlayerConfigurations[playerID];
	local leaderType = pPlayerConfig:GetLeaderTypeName();
	local loadingInfo:table = GameInfo.LoadingInfo[leaderType];
	if loadingInfo and loadingInfo.ForegroundImage then
		data.PlayerPortrait = loadingInfo.ForegroundImage;
	else
		data.PlayerPortrait = leaderType .. "_NEUTRAL";
	end

	local defeatInfo = GameInfo.Defeats[defeatType];
	if defeatInfo and defeatInfo.Name then
		data.RibbonText = Locale.ToUpper(defeatInfo.Name);
	else
		data.RibbonText = Locale.ToUpper("LOC_DEFEAT_DEFAULT_NAME");
	end
	
	-- Gather ribbon data
	local style = Styles[defeatType];
	if(style == nil) then
		style = Styles["GENERIC_DEFEAT"];
	end

	data.RibbonStyle = style;
	data.RibbonIcon = style.RibbonIcon or "ICON_DEFEAT_GENERIC";

	-- No winner so clear out winner name
	data.WinnerName = "";

	-- Defeated player data
	local pDefeatedConfig = PlayerConfigurations[playerID];
	local pDefeatedPlayer = Players[playerID];
	data.DefeatedName = Locale.Lookup(pDefeatedConfig:GetCivilizationDescription());
	if GameConfiguration.IsAnyMultiplayer() and pDefeatedPlayer:IsHuman() then
		local defeatedName = Locale.Lookup(pDefeatedConfig:GetPlayerName());
		data.DefeatedName = data.DefeatedName .. " (" .. defeatedName .. ")"
	end

	local defeatedCivType = pDefeatedConfig:GetCivilizationTypeName();
	data.DefeatedIcon = "ICON_" .. defeatedCivType;

	local backColor, frontColor = UI.GetPlayerColors(playerID);
	data.DefeatedFrontColor = frontColor;
	data.DefeatedBackColor = backColor;

	local defeat = GameInfo.Defeats[defeatType];
	if (defeat) then
		data.OneMoreTurn = defeat.OneMoreTurn;

		-- KLUDGE
		-- This is a kludge for hot-seat games to avoid a soft hang.
		-- What's happening is the local player is still in the process of handling their defeat
		-- The cache of whether other players are alive hasn't been updated for the other players yet
		-- so end-game thinks other players are alive and the game can be resumed.
		data.NoMorePlayers= defeat.Global;
	end
	print("PlayerDefeatedData",data.DefeatedName)
	return data;
end

----------------------------------------------------------------
function TeamVictoryData(winningTeamID:number, victoryType:string)
	local data:table = DefaultData();
	local localPlayerID:number = Game.GetLocalPlayer();
	local pLocalPlayer:table = Players[localPlayerID];
	local localPlayerTeamID:number = pLocalPlayer:GetTeam();

	data.viewerPlayer = localPlayerID;  -- team victory is always displayed from the perspective of the local player.
	
	-- Determine if the local player is a winner
	data.IsWinnerLocalPlayer = winningTeamID == localPlayerTeamID;

	-- Remember the winning team so UpdateButtonStates() can use it. 
	data.WinningTeamID = winningTeamID;

	local victoryStyle = Styles[victoryType];
	if not victoryStyle then
		if data.IsWinnerLocalPlayer then
			victoryStyle = Styles["GENERIC_VICTORY"];
		else
			victoryStyle = Styles["GENERIC_DEFEAT"];
		end
	end

	-- Gather player portrait data
	-- The portrait should be the first living player in the winning team.
	local playerToShow = localPlayerID; -- default to local player, if something weird happens.
	local team = Teams[winningTeamID];
	for i, v in ipairs(team) do
		local player = Players[v];
		if(player:IsAlive()) then
			playerToShow = v;
			break;
		end
	end

	local pPlayerConfig = PlayerConfigurations[playerToShow];
	local leaderType = pPlayerConfig:GetLeaderTypeName();
	local loadingInfo:table = GameInfo.LoadingInfo[leaderType];
	if loadingInfo and loadingInfo.ForegroundImage then
		data.PlayerPortrait = loadingInfo.ForegroundImage;
	else
		data.PlayerPortrait = leaderType .. "_NEUTRAL";
	end

	-- Gather ribbon data
	if data.IsWinnerLocalPlayer then
		data.RibbonText = Locale.ToUpper("LOC_VICTORY_DEFAULT_NAME");
		data.RibbonIcon = "ICON_VICTORY_UNIVERSAL";
		data.RibbonStyle = victoryStyle;
		if(data.RibbonStyle == nil) then
			data.RibbonStyle = Styles["GENERIC_VICTORY"];
		end
	else
		data.RibbonText = Locale.ToUpper("LOC_DEFEAT_DEFAULT_NAME");
		data.RibbonIcon = "ICON_DEFEAT_GENERIC";
		data.RibbonStyle = Styles["GENERIC_DEFEAT"];
	end

	-- Gather winner data
	local victory = GameInfo.Victories[victoryType];
	data.VictoryTypeHeader = victory.Name;
	data.VictoryTypeIcon = victoryStyle.RibbonIcon;
	if victoryStyle.Color then
		data.VictoryTypeColor = victoryStyle.Color;
	end
	data.OneMoreTurn = victory.OneMoreTurn;

	-- Display victory blurb if local player is the winner
	if data.IsWinnerLocalPlayer then
		data.VictoryBlurb = Locale.Lookup(victory.Blurb);
	else
		data.VictoryBlurb = "";
	end

	if #Teams[winningTeamID] > 1 then
		-- Show team info if more than one player on a team
		data.WinnerName = Locale.Lookup("LOC_WORLD_RANKINGS_TEAM", winningTeamID);
		data.WinnerIcon = "ICON_TEAM_ICON_" .. winningTeamID;
		data.WinnerBackColor = GetTeamColor(winningTeamID);
		data.WinnerFrontColor = UI.GetColorValue("COLOR_WHITE");
	else
		-- Show player info if only one player on team
		local winnerPlayerID:number = Teams[winningTeamID][1];
		local pWinnerConfig = PlayerConfigurations[winnerPlayerID];
		local pWinnerPlayer = Players[winnerPlayerID];
		data.WinnerName = Locale.Lookup(pWinnerConfig:GetCivilizationDescription());
		if GameConfiguration.IsAnyMultiplayer() and pWinnerPlayer:IsHuman() then
			local winnerName = Locale.Lookup(pWinnerConfig:GetPlayerName());
			data.WinnerName = data.WinnerName .. " (" .. winnerName .. ")"
		end

		local winnerCivType = pWinnerConfig:GetCivilizationTypeName();
		data.WinnerIcon = "ICON_" .. winnerCivType;

		local backColor, frontColor = UI.GetPlayerColors(winnerPlayerID);
		data.WinnerFrontColor = frontColor;
		data.WinnerBackColor = backColor;
	end

	-- Gather defeated data
	if data.IsWinnerLocalPlayer then
		-- No defeated name indicates we should hide the whole panel
		-- We hide this panel unless the winning player is not the local player
		data.DefeatedName = "";
	else
		local pDefeatedConfig = PlayerConfigurations[localPlayerID];
		local pDefeatedPlayer = Players[localPlayerID];
		data.DefeatedName = Locale.Lookup(pDefeatedConfig:GetCivilizationDescription());
		if GameConfiguration.IsAnyMultiplayer() and pDefeatedPlayer:IsHuman() then
			local defeatedName = Locale.Lookup(pDefeatedConfig:GetPlayerName());
			data.DefeatedName = data.DefeatedName .. " (" .. defeatedName .. ")"
		end

		local defeatedCivType = pDefeatedConfig:GetCivilizationTypeName();
		data.DefeatedIcon = "ICON_" .. defeatedCivType;

		local backColor, frontColor = UI.GetPlayerColors(localPlayerID);
		data.DefeatedFrontColor = frontColor;
		data.DefeatedBackColor = backColor;
	end
	
	return data;
end

----------------------------------------------------------------
-- Called when a player has been defeated.
----------------------------------------------------------------
function OnPlayerDefeat( player, defeat, eventID)	
	local localPlayer :number= Game.GetLocalPlayer();
	local defeatPlayer = Players[player];
	if ((localPlayer and localPlayer >= 0 and localPlayer == player) -- local player was defeated, show screen
		or (GameConfiguration.IsHotseat() and defeatPlayer ~= nil and defeatPlayer:IsHuman())) then -- Hotseat Only - Another human player was defeated 
		-- [TTP 44380] Only display PlayerDefeat if we are not already displaying the end game.
		-- Mechanically, this means that all other victory/defeat types stomp on PlayerDefeated but PlayerDefeated will not stomp any other end game.
		-- We do this because the PlayerDefeat signal can be in a race condition with other victory/defeats typed to this player being defeated.
		-- We want to prioritize the other victory/defeat for display.
		if(ContextPtr:IsHidden() == false or m_waitingForShow == true) then
			return;
		end

		-- Show the defeat screen.
		m_isFadeOutGame = true;
		UI.SetPauseEventID( eventID );
		local defeatInfo = GameInfo.Defeats[defeat];
		defeat = defeatInfo and defeatInfo.DefeatType or "DEFEAT_DEFAULT";
		View(PlayerDefeatedData(player, defeat));
		
		-- In hotseat games, it is possible for a human player to get defeated by an AI civ during turn processing.
		-- We trigger an event so the PlayerChange screen can hide itself.
		LuaEvents.EndGameMenu_ViewingPlayerDefeat();
	end
end

----------------------------------------------------------------
-- Called when a player is victorious.
-- The UI is only displayed if this player is you.
----------------------------------------------------------------
function OnTeamVictory(team, victory, eventID)
	m_teamVictory = true;
	local localPlayer :number = Game.GetLocalPlayer();
	if (localPlayer and localPlayer >= 0) then		-- Check to see if there is any local player
		m_isFadeOutGame = true;
		
		-- [TTP 34847] Handle the specific case where the local player was defeated and it resulted in game victory.  
		-- It is possible that PlayerDefeat was processed first.  In that case the player defeated screen is visible but the game is not paused.
		if(ContextPtr:IsHidden() == false) then
			HandlePauseGame(false);
		end

		UI.SetPauseEventID( eventID );	-- Set the pause event, the closing of the end game screen will release it.
		local victoryInfo = GameInfo.Victories[victory];
		victory = victoryInfo and victoryInfo.VictoryType or "VICTORY_DEFAULT";
		View(TeamVictoryData(team, victory));
	end
end

-- =============================================================
function OnShowEndGame(playerID : number)
	ShowEndGame(playerID);
end

----------------------------------------------------------------
-- Called when the display is to be manually shown.
----------------------------------------------------------------
function ShowEndGame(playerId : number)
	if(playerId == nil) then
		playerId = Game.GetLocalPlayer();
	end

	if(playerId ~= PlayerTypes.NO_PLAYER)then
		local player : table = Players[playerId];
		if(player:IsAlive()) then
			local victor, victoryType = Game.GetWinningTeam();
			if(victor == player:GetTeam()) then
				local victory = GameInfo.Victories[victoryType];
				if(victory) then
					View(TeamVictoryData(victor, victory.VictoryType));
					return;
				end
			end
		end
	end

	View(PlayerDefeatedData(playerId, "DEFEAT_DEFAULT"));
end

-- ===========================================================================
--	Concede Functions
-- ===========================================================================

function OnConcede()
	local playerId = Network.GetLocalPlayerID();
	if playerId ~= nil then
		playerId = Game.GetLocalPlayer();
	end
	m_concede = true
	m_isFadeOutGame = true
	View(PlayerDefeatedData(playerId, "DEFEAT_CONCEDE"));
end

function OnWinByConcede(victorytype:string)
	local playerId = Network.GetLocalPlayerID();
	if victorytype == nil then
		victorytype = "VICTORY_CONCEDE"
	end
	if playerId ~= nil then
		playerId = Game.GetLocalPlayer();
	end
	m_concede = true
	m_isFadeOutGame = true
	View(TeamVictoryData(Players[playerId]:GetTeam(), victorytype));
end

-- ===========================================================================
--	Chat Panel Functionality
-- ===========================================================================
function OnChat( fromPlayer:number, toPlayer:number, text:string, eTargetType:number )
	-- EndGameMenu doesn't play sounds for chat events because the ingame chat panel (which is hidden) already does so. 
	if (ContextPtr:IsHidden() == false and fromPlayer ~= Network.GetLocalPlayerID()) then
		UI.PlaySound("Play_MP_Chat_Message_Received");
	end

	local pPlayerConfig :object = PlayerConfigurations[fromPlayer];
	local playerName	:string = Locale.Lookup(pPlayerConfig:GetPlayerName());

	-- Selecting chat text color based on eTargetType	
	local chatColor :string = "[color:ChatMessage_Global]";
	if(eTargetType == ChatTargetTypes.CHATTARGET_TEAM) then
		chatColor = "[color:ChatMessage_Team]";
	elseif(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER) then
		chatColor = "[color:ChatMessage_Whisper]";  
	end
		
	local chatString	= "[color:ChatPlayerName]" .. playerName;

	-- When whispering, include the whisperee's name as well.
	if(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER) then
		local pTargetConfig :table	= PlayerConfigurations[toPlayer];
		if(pTargetConfig ~= nil) then
			local targetName = Locale.Lookup(pTargetConfig:GetPlayerName());
			chatString = chatString .. " [" .. targetName .. "]";
		end
	end

	-- Ensure text parsed properly
	text = ParseChatText(text);

	chatString			= chatString .. ": [ENDCOLOR]" .. chatColor;
	chatString			= chatString .. text .. " [ENDCOLOR]";

	AddChatEntry( chatString, Controls.ChatStack, m_ChatInstances, Controls.ChatScroll);
end

-------------------------------------------------
-------------------------------------------------
function SendChat( text )
    if( string.len( text ) > 0 ) then
		-- Parse text for possible chat commands
		local parsedText :string;
		local chatTargetChanged :boolean = false;
		local printHelp :boolean = false;
		parsedText, chatTargetChanged, printHelp = ParseInputChatString(text, m_playerTarget);
		if(chatTargetChanged) then
			ValidatePlayerTarget(m_playerTarget);
			UpdatePlayerTargetPulldown(Controls.ChatPull, m_playerTarget);
			UpdatePlayerTargetEditBox(Controls.ChatEntry, m_playerTarget);
			UpdatePlayerTargetIcon(Controls.ChatIcon, m_playerTarget);
		end

		if(printHelp) then
			ChatPrintHelp(Controls.ChatStack, m_ChatInstances, Controls.ChatScroll);
		end

		if(parsedText ~= "") then
			-- m_playerTarget uses PlayerTargetLogic values and needs to be converted  
			local chatTarget :table ={};
			PlayerTargetToChatTarget(m_playerTarget, chatTarget);
			Network.SendChat( parsedText, chatTarget.targetType, chatTarget.targetID );
			UI.PlaySound("Play_MP_Chat_Message_Sent");
		end
    end
    Controls.ChatEntry:ClearString();
end

-------------------------------------------------
-- ParseChatText - ensures icon tags parsed properly
-------------------------------------------------
function ParseChatText(text)
	startIdx, endIdx = string.find(string.upper(text), "%[ICON_");
	if(startIdx == nil) then
		return text;
	else
		for i = endIdx + 1, string.len(text) do
			character = string.sub(text, i, i);
			if(character=="]") then
				return string.sub(text, 1, i) .. ParseChatText(string.sub(text,i + 1));
			elseif(character==" ") then
				text = string.gsub(text, " ", "]", 1);
				return string.sub(text, 1, i) .. ParseChatText(string.sub(text, i + 1));
			elseif (character=="[") then
				return string.sub(text, 1, i - 1) .. "]" .. ParseChatText(string.sub(text, i));
			end
		end
		return text.."]";
	end
	return text;
end

-------------------------------------------------
-------------------------------------------------

function OnMultplayerPlayerConnected( playerID )
	-- EndGameMenu doesn't play sounds for chat events because the ingame chat panel already does so. 
	if( ContextPtr:IsHidden() == false ) then
		OnChat( playerID, -1, PlayerConnectedChatStr);
	end
end

-------------------------------------------------
-------------------------------------------------

function OnMultiplayerPrePlayerDisconnected( playerID )
	-- EndGameMenu doesn't play sounds for chat events because the ingame chat panel already does so. 
	if( ContextPtr:IsHidden() == false ) then
		if(Network.IsPlayerKicked(playerID)) then
			OnChat( playerID, -1, PlayerKickedChatStr);
		else
    		OnChat( playerID, -1, PlayerDisconnectedChatStr);
		end
	end
end

----------------------------------------------------------------
function OnMultiplayerHostMigrated( newHostID : number )
	-- EndGameMenu doesn't play sounds for chat events because the ingame chat panel already does so. 
	if(ContextPtr:IsHidden() == false) then
		OnChat( newHostID, -1, PlayerHostMigratedChatStr);
	end
end

----------------------------------------------------------------
function OnPlayerInfoChanged(playerID)
	if(ContextPtr:IsHidden() == false) then
		-- Update chat target pulldown.
		PlayerTarget_OnPlayerInfoChanged( playerID, Controls.ChatPull, Controls.ChatEntry, Controls.ChatIcon, m_playerTargetEntries, m_playerTarget, false);
	end
end

----------------------------------------------------------------
function OnChatPulldownChanged(newTargetType :number, newTargetID :number)
	local textControl:table = Controls.ChatPull:GetButton():GetTextControl();
	local text:string = textControl:GetText();
	Controls.ChatPull:SetToolTipString(text);
end

-- ===========================================================================
function OnRequestClose()
	if (not g_kPopupDialog:IsOpen()) then
		g_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_QUIT_WARNING"));
		g_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), nil );
		g_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnExitGame, nil, nil, "PopupButtonInstanceRed" );
		g_kPopupDialog:Open();
	end
end

-- ===========================================================================
function OnExitGame()
	local pFriends = Network.GetFriends();
	if pFriends ~= nil then
		pFriends:ClearRichPresence();
	end

	Events.UserConfirmedClose();
end


-- ===========================================================================
function LateInitialize()
	Resize();
end

-- ===========================================================================
function OnInit( isReload:boolean )
	LateInitialize();
	if isReload then
		LuaEvents.GameDebug_GetValues( RELOAD_CACHE_ID );
	end
end

-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "IsHidden", ContextPtr:IsHidden() );
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_savedData", m_savedData );
end

-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then
		local isHidden:boolean = contextTable["IsHidden"];
		if not isHidden then
			m_savedData = contextTable["m_savedData"];
			if m_savedData then
				m_isFadeOutGame = true;
				View( m_savedData );
				OnShow();	-- Need to force since already on the stack
			end
		end
	end
end

-- ===========================================================================
--	Initialize screen
-- ===========================================================================
function Initialize()

	-- UI Callbacks
	local player = Players[Game.GetLocalPlayer()];
	if player ~= nil then
		if PlayerConfigurations[Game.GetLocalPlayer()]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
			m_spec = true
		end
	end

	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetHideHandler( OnHide );
	ContextPtr:SetShutdown( OnShutdown );

	Controls.ChatEntry:RegisterCommitCallback( SendChat );

	TruncateStringWithTooltip(Controls.NextPlayerButton, MAX_BUTTON_SIZE, Locale.Lookup("LOC_UI_ENDGAME_MP_PLAYER_CHANGE_CONTINUE"));
	Controls.NextPlayerButton:RegisterCallback( Mouse.eLClick, OnNextPlayer );
	Controls.NextPlayerButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	TruncateStringWithTooltip(Controls.MainMenuButton, MAX_BUTTON_SIZE, Locale.Lookup("LOC_UI_ENDGAME_MAIN_MENU"));
	Controls.MainMenuButton:RegisterCallback( Mouse.eLClick, OnMainMenu );
	Controls.MainMenuButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	TruncateStringWithTooltip(Controls.BackButton, MAX_BUTTON_SIZE, Locale.Lookup("LOC_UI_ENDGAME_EXTENDED_GAME"));
	Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack );
	Controls.BackButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Controls.FadeButton:RegisterCallback( Mouse.eRClick, OnFadeAbort );

	Controls.InfoButton:RegisterCallback( Mouse.eLClick, OnInfoTab );
	Controls.InfoButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.RankingButton:RegisterCallback( Mouse.eLClick, OnRankingTab );
	Controls.RankingButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ReplayButton:RegisterCallback( Mouse.eLClick, OnReplayTab );
	Controls.ReplayButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ChatButton:RegisterCallback( Mouse.eLClick, OnChatTab );
	Controls.ChatButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	TruncateStringWithTooltip(Controls.ReplayMovieButton, MAX_BUTTON_SIZE, Locale.Lookup("LOC_UI_ENDGAME_REPLAY_MOVIE"));
	Controls.ReplayMovieButton:RegisterCallback(Mouse.eLClick, OnReplayMovie);
	Controls.ReplayMovieButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Controls.Movie:SetMovieFinishedCallback( OnMovieExitOrFinished );
	Controls.MovieFill:RegisterCallback(Mouse.eLClick, OnMovieExitOrFinished);
	
	-- XP1
	TruncateStringWithTooltip(Controls.HistoricMoments, MAX_BUTTON_SIZE, Locale.Lookup("LOC_END_GAME_MENU_HISTORIAN_BUTTON"));
	Controls.HistoricMoments:RegisterCallback( Mouse.eLClick, OnHistoricMoments );
	Controls.HistoricMoments:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	TruncateStringWithTooltip(Controls.ExportHistoricMoments, MAX_BUTTON_SIZE, Locale.Lookup("LOC_END_GAME_MENU_EXPORT_HISTORIAN_BUTTON"));
	Controls.ExportHistoricMoments:RegisterCallback( Mouse.eLClick, OnExportHistoricMoments );
	Controls.ExportHistoricMoments:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);


	if GameInfo.GameCapabilities("CAPABILITY_HISTORIC_MOMENTS") then
		TruncateStringWithTooltip(Controls.HistoricMoments, MAX_BUTTON_SIZE, Locale.Lookup("LOC_END_GAME_MENU_HISTORIAN_BUTTON"));
		Controls.HistoricMoments:RegisterCallback( Mouse.eLClick, OnHistoricMoments );
		Controls.HistoricMoments:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

		TruncateStringWithTooltip(Controls.ExportHistoricMoments, MAX_BUTTON_SIZE, Locale.Lookup("LOC_END_GAME_MENU_EXPORT_HISTORIAN_BUTTON"));
		Controls.ExportHistoricMoments:RegisterCallback( Mouse.eLClick, OnExportHistoricMoments );
		Controls.ExportHistoricMoments:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	else
		Controls.HistoricMoments:SetHide(true);
		Controls.ExportHistoricMoments:SetHide(true);
	end

	-- Events

	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);	
	LuaEvents.ShowEndGame.Add(ShowEndGame);
	LuaEvents.MPHMenu_Concede.Add(OnConcede);
	LuaEvents.MPHMenu_ConcedeWin.Add(OnWinByConcede);
	
	Events.SystemUpdateUI.Add( OnUpdateUI );
	Events.UserRequestClose.Add( OnRequestClose );
	Events.PlayerInfoChanged.Add( OnPlayerInfoChanged );
	Events.MultiplayerPrePlayerDisconnected.Add( OnMultiplayerPrePlayerDisconnected );
	Events.MultiplayerPlayerConnected.Add( OnMultplayerPlayerConnected );
	Events.MultiplayerChat.Add( OnChat );

	local ruleset :string = GameConfiguration.GetValue("RULESET");
	if ruleset ~= "RULESET_TUTORIAL" then
		Events.TeamVictory.Add(OnTeamVictory);
		Events.PlayerDefeat.Add(OnPlayerDefeat);
	end
end
include("EndGameMenu_", true);
Initialize();
 