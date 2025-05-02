# Introducción

Este reporte se ha realizado sobre uno de los retos que podemos encontrar en la plataforma online [Damn Vulnerable DeFi](https://www.damnvulnerabledefi.xyz/) llamado [Unstoppable](https://www.damnvulnerabledefi.xyz/challenges/unstoppable/). Las instruciones del reto se pueden consultar en la siguiente imagen:

![unstoppable instructions](https://github.com/user-attachments/assets/a4d58e32-0b14-48f8-891f-185b32ddbfdf)

> [!NOTE]
> **Traducción:**
> Hay una bóveda tokenizada con un millón de tokens DVT depositados. Ofrece préstamos flash gratuitos hasta que finalice el periodo de gracia.
>
>Para detectar cualquier error antes de ir 100% sin permisos, los desarrolladores decidieron ejecutar una beta en vivo en testnet. Hay un contrato de monitorización para comprobar la actividad de la función flashloan.
>
>Comenzando con 10 tokens DVT en saldo, muestra que es posible detener la bóveda. Debe dejar de ofrecer préstamos flash.
