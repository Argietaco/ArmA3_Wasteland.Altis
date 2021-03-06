#include "FAR_defines.sqf"

////////////////////////////////////////////////
// Player Actions
////////////////////////////////////////////////
FAR_Player_Actions =
{
	if (alive player && player isKindOf "Man") then
	{
		// addAction args: title, filename, (arguments, priority, showWindow, hideOnUse, shortcut, condition, positionInModel, radius, radiusView, showIn3D, available, textDefault, textToolTip)
		[aActionsIDs, player addAction ["<t color='#00C900'>" + "Revive" + "</t>", "addons\FAR_revive\FAR_handleAction.sqf", ["action_revive"], 100, true, true, "", "call FAR_Check_Revive"]] call BIS_fnc_arrayPush;
		[aActionsIDs, player addAction ["<t color='#00C900'>" + "Stabilize" + "</t>", "addons\FAR_revive\FAR_handleAction.sqf", ["action_stabilize"], 99, true, true, "", "call FAR_Check_Stabilize"]] call BIS_fnc_arrayPush;
		//player addAction ["<t color='#C90000'>" + "Suicide" + "</t>", "addons\FAR_revive\FAR_handleAction.sqf", ["action_suicide"], 9, false, true, "", "call FAR_Check_Suicide"];
		[aActionsIDs, player addAction ["<t color='#C9C900'>" + "Drag" + "</t>", "addons\FAR_revive\FAR_handleAction.sqf", ["action_drag"], 98, false, true, "", "call FAR_Check_Dragging && primaryWeapon _this != ''"]] call BIS_fnc_arrayPush;
		// the primary weapon check is because you can't move without a rifle while dragging
	};
}
call mf_compile;

////////////////////////////////////////////////
// Handle Death
////////////////////////////////////////////////
FAR_HandleDamage_EH = "addons\far_revive\FAR_HandleDamage_EH.sqf" call mf_compile;

////////////////////////////////////////////////
// Make Player Unconscious
////////////////////////////////////////////////
FAR_Player_Unconscious = "addons\far_revive\FAR_Player_Unconscious.sqf" call mf_compile;

////////////////////////////////////////////////
// Revive Player
////////////////////////////////////////////////
FAR_HandleRevive =
{
	private ["_target", "_medicMove"];
	_target = _this select 0;

	if (alive _target) then
	{
		_target setVariable ["FAR_treatedBy", player, true];

		_medicMove = format ["AinvPknlMstpSlayW%1Dnon_medic", [_target, true] call getMoveWeapon];
		player playMove _medicMove;

		waitUntil {sleep 0.1; animationState player == _medicMove || !CAN_PERFORM};
		waitUntil {sleep 0.1; animationState player != _medicMove || !CAN_PERFORM};

		if (CAN_PERFORM) then
		{
			_target setVariable ["FAR_isUnconscious", 0, true];

			// [Debugging] Code below is only relevant if revive script is enabled for AI
			if (!isPlayer _target) then
			{
				_target setDamage 0;
				_target setCaptive false;

				_target playMove format ["AmovPpneMstpSrasW%1Dnon", _target call getMoveWeapon];
			};
		};

		if (_target getVariable ["FAR_treatedBy", objNull] == player) then
		{
			_target setVariable ["FAR_treatedBy", nil, true];
		};
	};
}
call mf_compile;

////////////////////////////////////////////////
// Stabilize Player
////////////////////////////////////////////////
FAR_HandleStabilize =
{
	private ["_target", "_medicMove"];
	_target = _this select 0;

	if (alive _target) then
	{
		_target setVariable ["FAR_treatedBy", player, true];

		_medicMove = format ["AinvPknlMstpSlayW%1Dnon_medic", [_target, true] call getMoveWeapon];
		player playMove _medicMove;

		waitUntil {sleep 0.1; animationState player == _medicMove || !CAN_PERFORM};
		waitUntil {sleep 0.1; animationState player != _medicMove || !CAN_PERFORM};

		if (CAN_PERFORM) then
		{
			_target setVariable ["FAR_isStabilized", 1, true];

			if (isPlayer _target) then
			{
				_target setVariable ["FAR_handleStabilize", true, true];
			}
			else // [Debugging] Code below is only relevant if revive script is enabled for AI
			{
				_target setDamage 0.25;
			};

			if !("Medikit" in items player) then
			{
				player removeItem "FirstAidKit";
			};
		};

		if (_target getVariable ["FAR_treatedBy", objNull] == player) then
		{
			_target setVariable ["FAR_treatedBy", nil, true];
		};
	};
}
call mf_compile;

////////////////////////////////////////////////
// Drag Injured Player
////////////////////////////////////////////////
FAR_Drag =
{
	FAR_isDragging = true;

	private ["_target", "_id"];
	_target = _this select 0;

	player playMoveNow "AcinPknlMstpSrasWrflDnon";

	_target attachTo [player, [0, 1.1, 0.092]];
	_target setDir 180;
	_target setVariable ["FAR_draggedBy", player, true];

	// Rotation fix
	FAR_isDragging_EH = _target;
	publicVariable "FAR_isDragging_EH";

	// Add release action and save its id so it can be removed
	_id = player addAction ["<t color='#C90000'>" + "Release" + "</t>", "addons\FAR_revive\FAR_handleAction.sqf", ["action_release"], 10];

	player globalChat "Press ""C"" if you can't move.";
	player selectWeapon primaryWeapon player;

	// Drag & Carry animation fix
	[] spawn
	{
		while {FAR_isDragging} do
		{
			_animState = animationState player;

			if (_animState == "AcinPknlMstpSrasWrflDnon_AcinPercMrunSrasWrflDnon" || _animState == "helper_switchtocarryrfl") then
			{
				[player, "AcinPknlMstpSrasWrflDnon"] call switchMoveGlobal;
			};

			sleep 0.5;
		};
	};

	// Wait until release action is used
	waitUntil {!alive player || UNCONSCIOUS(player) || !alive _target || !UNCONSCIOUS(_target) || !FAR_isDragging || isNull DRAGGED_BY(_target)};

	if (!isNull _target) then
	{
		detach _target;
		_target setVariable ["FAR_draggedBy", nil, true];
	};

	FAR_isDragging = false;
	player playMove format ["AmovPknlMstpSrasW%1Dnon", player call getMoveWeapon];
	player removeAction _id;
}
call mf_compile;

FAR_Release =
{
	FAR_isDragging = false;
}
call mf_compile;

////////////////////////////////////////////////
// Event handler for public variables
////////////////////////////////////////////////
FAR_public_EH =
{
	if(count _this < 2) exitWith {};

	_EH  = _this select 0;
	_target = _this select 1;

	// FAR_isDragging
	if (_EH == "FAR_isDragging_EH") then
	{
		_target setDir 180;
	};

	// FAR_deathMessage
	if (_EH == "FAR_deathMessage") then
	{
		_unit = _target select 0;
		_killer = [_target, 1] call BIS_fnc_param;

		if (isNil "_killer") then
		{
			systemChat format ["%1 was injured", toString _unit];
		}
		else
		{
			systemChat format ["%1 was injured by %2", toString _unit, toString _killer];
		};
	};
}
call mf_compile;

////////////////////////////////////////////////
// Suicide Action Check
////////////////////////////////////////////////
FAR_Check_Suicide =
{
	UNCONSCIOUS(player)
}
call mf_compile;

////////////////////////////////////////////////
// Dragging Action Check
////////////////////////////////////////////////
FAR_Check_Dragging =
{
	_target = cursorTarget;

	if (isNil "_target" || {isNull _target}) exitWith {};

	// Make sure player is alive and target is an injured unit
	if (!alive player || UNCONSCIOUS(player) || FAR_isDragging || isNil "_target" ||
	   {!alive _target || (!isPlayer _target && !FAR_Debugging) || (_target distance player > 2) || !isNull (_target getVariable ["FAR_treatedBy", objNull])}) exitWith
	{
		false
	};

	// Make sure target is unconscious
	UNCONSCIOUS(_target) && !DRAGGED(_target)
}
call mf_compile;

////////////////////////////////////////////////
// Stabilize Action Check
////////////////////////////////////////////////
FAR_Check_Stabilize =
{
	call FAR_Check_Dragging && {!STABILIZED(cursorTarget) && ({_x in ["FirstAidKit","Medikit"]} count items player > 0)}
}
call mf_compile;

////////////////////////////////////////////////
// Revive Action Check
////////////////////////////////////////////////
FAR_Check_Revive =
{
	call FAR_Check_Dragging && IS_MEDIC(player)
}
call mf_compile;

////////////////////////////////////////////////
// Show Nearby Friendly Medics
////////////////////////////////////////////////
FAR_IsFriendlyMedic =
{
	IS_MEDIC(_this) && !UNCONSCIOUS(_this) && side _this == playerSide && {playerSide in [BLUFOR,OPFOR] || group _this == group player}
}
call mf_compile;

FAR_CheckFriendlies =
{
	private ["_units", "_msg", "_medics", "_dir", "_cardinal"];

	_units = player nearEntities ["AllVehicles", 1000];
	_msg = "<t underline='true'>Nearby medics</t>";
	_medics = "";

	{
		{
			if (alive _x && (_x != player) && (isPlayer _x || FAR_Debugging) && {_x call FAR_IsFriendlyMedic}) then
			{
				_dir = [player, _x] call BIS_fnc_dirTo;
				_cardinal = switch (true) do
				{
					case (_dir >= 337.5): { "N" };
					case (_dir >= 292.5): { "NW" };
					case (_dir >= 247.5): { "W" };
					case (_dir >= 202.5): { "SW" };
					case (_dir >= 157.5): { "S" };
					case (_dir >= 112.5): { "SE" };
					case (_dir >= 67.5):  { "E" };
					case (_dir >= 22.5):  { "NE" };
					default               { "N" };
				};

				_medics = _medics + format ["<br/>%1 - %2m %3", name _x, floor ((vehicle _x) distance player), _cardinal];
			};
		} forEach crew _x;
	} forEach _units;

	_msg + (if (_medics == "") then { "<br/>- none -" } else { _medics })
}
call mf_compile;
