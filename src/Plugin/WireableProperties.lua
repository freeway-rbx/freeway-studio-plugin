type PropertyData = {
    ClassName: string,
    Properties: {string},
}

local wireableProperties: {string: {PropertyData}}  = {
     
    mesh = {
        MeshPart = {"MeshId"}
    },
    image = {
        AdGui = {
            TextureID = {editableImage=false, localAsset=true}},
        BackpackItem = {
            TextureId = {editableImage=false, localAsset=true}},
        Beam = {
            Texture =  {editableImage=false, localAsset=true}},
        ClickDetector = {
            CursorIcon = {editableImage=false, localAsset=true}},
        Decal = {
            Texture = {editableImage=false, localAsset=true, editableProperty='TextureContent'}},
        DragDetector = {
            ActivatedCursorIcon = {editableImage=false, localAsset=true}},
        FileMesh = {
            TextureId = {editableImage=false, localAsset=true}},
        FloorWire = {
            Texture = {editableImage=false, localAsset=true}},
        ImageButton = {
            Image = {editableImage=false, localAsset=true, editableProperty='ImageContent'}, 
            HoverImage = {editableImage=false, localAsset=true}, 
            PressedImage = {editableImage=false, localAsset=true}},
        ImageHandleAdornment = {
            Image = {editableImage=false, localAsset=true}},
        ImageLabel = {
            Image = {editableImage=false, localAsset=true, editableProperty='ImageContent'}},
        MaterialVariant = {
            ColorMap = {editableImage=false, localAsset=false}, 
            MetalnessMap = {editableImage=false, localAsset=false}, 
            NormalMap = {editableImage=false, localAsset=false}, 
            RoughnessMap = {editableImage=false, localAsset=false}},
        MeshPart = {
            TextureID = {editableImage=false, localAsset=true, editableProperty='TextureContent'}},
        Mouse = {
            Icon = {editableImage=false, localAsset=true}},
        Pants = { 
            PantsTemplate = {{editableImage=false, localAsset=true}}},
        ParticleEmitter = {
            Texture = {editableImage=false, localAsset=true}},
        PluginToolbarButton = {
            Icon = {editableImage=false, localAsset=true}},
        ScreenshotHud = {
            CameraButtonIcon = {editableImage=false, localAsset=true}},
        ScrollingFrame = {
            MidImage = {editableImage=false, localAsset=true}, 
            TopImage = {editableImage=false, localAsset=true}, 
            BottomImage = {editableImage=false, localAsset=true}},
        Shirt = {
            ShirtTemplate = {editableImage=false, localAsset=true}},
        ShirtGraphic = {
            Graphic = {editableImage=false, localAsset=true}},
        Sky = {
            SkyboxBk = {editableImage=false, localAsset=true}, 
            SkyboxDn = {editableImage=false, localAsset=true}, 
            SkyboxFt = {editableImage=false, localAsset=true}, 
            SkyboxLf = {editableImage=false, localAsset=true}, 
            SkyboxRt = {editableImage=false, localAsset=true}, 
            SkyboxUp = {editableImage=false, localAsset=true}, 
            SunTextureId = {editableImage=false, localAsset=true}, 
            MoonTextureId = {editableImage=false, localAsset=true}},
        SurfaceAppearance = {
            ColorMap = {editableImage=false, localAsset=false}, 
            MetalnessMap = {editableImage=false, localAsset=false}, 
            NormalMap = {editableImage=false, localAsset=false}, 
            RoughnessMap = {editableImage=false, localAsset=false}},
        TerrainDetail = {
            ColorMap = {editableImage=false, localAsset=false}, 
            MetalnessMap = {editableImage=false, localAsset=false}, 
            NormalMap = {editableImage=false, localAsset=false}, 
            RoughnessMap = {editableImage=false, localAsset=false}},
        Texture = {
            Texture = {editableImage=false, localAsset=true}},
        Trail = {
            Texture = {editableImage=false, localAsset=true}},
        UserInputService = {
            MouseIcon = {editableImage=false, localAsset=true}},
    }, 
    

}

function wireableProperties:get_image_property_configuration(className, propertyName): {}
    local instanceType = self['image'][className]
    if instanceType == nil then return nil end
    return instanceType[propertyName]
end


return wireableProperties