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

Nuestro objetivo es por tanto buscar una forma de detener el contrato que ofrece flash loans, esto de detener un contrato se refiere a una funcionalidad que ha implementado OpenZeppelin donde el creador del contrato o cualquiera que tenga permisos puede "pausar" un contrato como si fuera una parada de emergencia, no es una parada estrictamente dicha (porque no se puede parar un contrato) sino más bien se restringe el uso de ciertas funciones si la variable de pausa esta activada, para más informacion consultar el siguiente enlace.

# Análisis de nuestro reto

Bien definidos los conceptos del reto podemos pasar a realizar el análisis de los contratos presentes.

## Contrato `UnstoppableVault.sol`

Vamos a empezar con el constructor del contrato que se vería de la siguiente manera:

![vault constructor](https://github.com/user-attachments/assets/f9835396-df44-4b0f-b09e-c22008bde5c1)

Como podemos observar este contrato inicializa el token `ERC4626`, que es un estándar de bóveda tokenizada que permite a los usuarios depositar tokens ERC20 en una bóveda y recibir acciones que representan su participación en los activos de la bóveda, y el contrato `Owned`, que es un contrato que gestiona la propiedad del contrato que lo hereda, en este caso el propietario del contrato es la dirección que haya sido pasada por parámetro al constructor (`_owner`) y por último tenemos una dirección que será la cual reciba los `fees` o tarifas que se cobren por pedir el flash loan.

A continuación me voy a centrar en una de las funciones en concreto del contrato en estudio, la función `flashLoan()`, que se vería de la siguiente forma:

![flashLoan function](https://github.com/user-attachments/assets/2d8f7201-9788-4148-9b16-94b110caa3e3)
