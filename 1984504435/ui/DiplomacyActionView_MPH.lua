
print("DiplomacyActionView for MPH")

-- Copyright 2017-2018, Firaxis Games

-- ===========================================================================
-- INCLUDE BASE FILE
-- ===========================================================================
include("DiplomacyActionView_Expansion2");

-- ===========================================================================
function AddIntelAlliance(tabContainer:table)
	print(" AddIntelAlliance(tabContainer:table)")
	-- Don't show the alliance tab if we're in a team with the selected player
	if ms_SelectedPlayer:GetTeam() == ms_LocalPlayer:GetTeam() then
		if m_AllianceTabContext then
			m_AllianceTabContext:SetHide(false);
		end
		--return;
	end

	-- Create tab
	local tabAnchor = GetTabAnchor(tabContainer);
	if m_AllianceTabContext == nil then
		m_AllianceTabContext = ContextPtr:LoadNewContext("DiplomacyActionView_AllianceTab", tabAnchor.Anchor);
	else
		m_AllianceTabContext:ChangeParent(tabAnchor.Anchor);
	end

	m_AllianceTabContext:SetHide(false);

	-- Create tab button
	local tabButtonInstance:table = CreateTabButton();
	tabButtonInstance.Button:RegisterCallback( Mouse.eLClick, function() ShowPanel(tabAnchor.Anchor); end );
	tabButtonInstance.Button:SetToolTipString(Locale.Lookup("LOC_DIPLOACTION_ALLIANCE_TAB_TOOLTIP"));
	tabButtonInstance.ButtonIcon:SetIcon("ICON_STAT_ALLIANCES");

	-- Cache references to the button instance and header text on the panel instance
	tabAnchor.Anchor.m_ButtonInstance = tabButtonInstance;
	tabAnchor.Anchor.m_HeaderText = Locale.ToUpper("LOC_DIPLOACTION_INTEL_REPORT_ALLIANCE");
end