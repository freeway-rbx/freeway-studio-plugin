local theme = settings().Studio.Theme

local enum = {
	FontSizeTextPrimary = 15,
	FontSizeTextSecondary = 13,
	FontSizeHeader = 20,
	FontSizeNavigationButton = 20,

	PaddingHorizontal = 20,
	PaddingVertical = 2,
	PaddingVerticalTight = 4,

	ColorBackground = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
	ColorButtonBackground = theme:GetColor(Enum.StudioStyleGuideColor.Button),
	ColorBackgroundHighlight = Color3.fromRGB(150, 100, 0),

	ColorTextPrimary = theme:GetColor(Enum.StudioStyleGuideColor.DialogButtonText),
	ColorTextSecondary = theme:GetColor(Enum.StudioStyleGuideColor.DialogButtonText),

	ColorButtonNavigationText = theme:GetColor(Enum.StudioStyleGuideColor.DialogButtonText),
	ColorButtonNavigationBackground = theme:GetColor(Enum.StudioStyleGuideColor.Light),

	ColorButtonSecondaryActionText = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
	ColorButtonSecondaryActionBackground = Color3.fromRGB(194, 194, 166),

	PreviewSize = 62,

	DetailsSize = 120,

	WIRED_NOT = 0,
	WIRED_MIXED = 1,
	WIRED_ALL_CURRENT = 2,
	WIRED_ALL_OTHER = 3,
	WIRED_TO_CURRENT_AND_UNWIRED = 4,
}

return enum
