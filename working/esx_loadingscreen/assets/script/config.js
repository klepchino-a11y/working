Config = {}; // Don't touch

Config.ServerIP = "westside.ws:30120";

// Social media buttons on the left side
Config.Socials = [
    {name: "discord", label: "ديسكورد WestSide", description: "انضم إلى مجتمع WS وتابع آخر الأخبار والفعّاليات.", icon: "assets/media/icons/discord.png", link: "https://discord.gg/westside"},
    {name: "tiktok", label: "تيك توك WS", description: "لقطات يومية من أحداث المنطقة الغربية.", icon: "assets/media/icons/tiktok.png", link: "https://www.tiktok.com/@westside"},
    {name: "tebex", label: "متجر WestSide", description: "ادعم السيرفر واحصل على مزايا حصرية.", icon: "assets/media/icons/tebex.png", link: "https://westside-shop.tebex.io/"},
];

Config.HideoverlayKeybind = 112 // JS key code https://keycode.info
Config.CustomBindText = "F1"; // leave as "" if you don't want the bind text in html to be statically set

// Staff list
Config.Staff = [
    {name: "[WS] أبو راكان", description: "Founder & Lead Dev", color: "#f7d34c", image: "assets/media/logo.png"},
    {name: "[WS] ريم", description: "Community Manager", color: "#3f9e63", image: "assets/media/logo.png"},
    {name: "[WS] سالم", description: "Support Lead", color: "#9bd984", image: "assets/media/logo.png"},
];

// Categories
Config.Categories = [
    {label: "روابط WestSide", default: true},
    {label: "طاقم الإدارة", default: false}
];

// Music
Config.Song = "song.mp3";
