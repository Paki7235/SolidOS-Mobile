"""Condivisione Vicina: servizio unico per inviare e ricevere file con telefoni e computer.

Backend (in ordine di preferenza predefinito): Quick Share (Android),
LocalSend (tutte le piattaforme con l'app), QR (qualsiasi telefono con un browser).
Il servizio espone l'interfaccia D-Bus org.<OS_ID>.Condivisione1 sul bus di sessione.
"""

PORTA_LOCALSEND = 53317
PORTA_QR = 53318
PORTA_QUICKSHARE = 53319

DURATA_TUTTI = 600          # «Tutti per 10 minuti»
DURATA_QR = 600             # scadenza del codice QR
