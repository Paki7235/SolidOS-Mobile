# Sicurezza di SolidOS Mobile

## Segnalare un problema di sicurezza

Se trovi un problema che mette a rischio chi usa SolidOS Mobile (dati personali, accesso al sistema,
aggiornamenti), **non aprire una issue pubblica**. Usa la segnalazione privata di GitHub:
scheda **Security** di questo progetto → **Report a vulnerability**. Rispondiamo il prima
possibile e, una volta corretto il problema, lo rendiamo pubblico ringraziando chi l'ha trovato.

## Aggiornamenti firmati

Ogni aggiornamento di SolidOS Mobile è firmato con la chiave Ed25519 del progetto. La chiave segreta
sta solo nei segreti delle build su GitHub e presso chi mantiene il progetto; il sistema
installato ha la chiave pubblica (`telefono/solidos-mobile/chiave-aggiornamenti.pem`) e rifiuta qualsiasi aggiornamento con una firma
mancante o diversa. Prima di installare, il sistema verifica anche la somma SHA-256 del
pacchetto, che fa parte della scheda firmata.

Impronta SHA-256 della chiave pubblica:

```
26c095015c96c80f7264dd03c1f5d819ddc7f567c4acda307d3ec121764e2f98
```

Per verificarla: `openssl pkey -pubin -in telefono/solidos-mobile/chiave-aggiornamenti.pem -outform DER | sha256sum`
