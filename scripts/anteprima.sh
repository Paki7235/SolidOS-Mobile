#!/bin/sh
# Avvia l'interfaccia di SolidOS Mobile in una finestra grande come un telefono.
# Esempi:  scripts/anteprima.sh
#          scripts/anteprima.sh --schermata=home --tema=chiaro
#          scripts/anteprima.sh --schermata=libreria --foto=libreria.png
RADICE=$(cd "$(dirname "$0")/.." && pwd)
export PYTHONPATH="$RADICE/src${PYTHONPATH:+:$PYTHONPATH}"
export NUCLEO_BRANDING="$RADICE/branding.env"
export NUCLEO_QML="$RADICE/src/qml"
# Alcune distribuzioni (es. Kali) impostano il tema GTK per le app Qt: senza uno schermo
# grafico (VNC, foto) chiude il programma all'avvio, e SolidOS usa comunque il suo stile
unset QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE
# Senza desktop (SSH, WSL, console): se non è stato scelto altro, si apre via VNC
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${QT_QPA_PLATFORM:-}" ]; then
	case " $* " in
		*" --foto="*) export QT_QPA_PLATFORM=offscreen ;;
		*)
			export QT_QPA_PLATFORM="vnc:size=430x900"
			echo "Nessuno schermo grafico: SolidOS Mobile è visibile via VNC sulla porta 5900"
			echo "(da questo computer: localhost:5900, da un altro: IP-DI-QUESTO-COMPUTER:5900). Ctrl+C per chiudere." ;;
	esac
fi
exec python3 -m nucleo.mobile "$@"
