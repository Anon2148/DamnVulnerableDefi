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

Nuestro objetivo es por tanto buscar una forma de detener el contrato que ofrece flash loans, esto de detener un contrato se refiere a una funcionalidad que ha implementado OpenZeppelin donde el creador del contrato o cualquiera que tenga permisos puede "pausar" un contrato como si fuera una parada de emergencia, no es una parada estrictamente dicha (porque no se puede parar un contrato) sino más bien se restringe el uso de ciertas funciones si la variable de pausa esta activada, para más informacion consultar el siguiente [enlace](https://docs.openzeppelin.com/contracts/5.x/api/utils#Pausable).

# Análisis de nuestro reto

Bien definidos los conceptos del reto podemos pasar a realizar el análisis de los contratos presentes.

## Contrato `UnstoppableVault.sol`

Vamos a empezar con el constructor del contrato que se vería de la siguiente manera:

![vault constructor](https://github.com/user-attachments/assets/f9835396-df44-4b0f-b09e-c22008bde5c1)

Como podemos observar este contrato inicializa el token `ERC4626`, que es un estándar de bóveda tokenizada que permite a los usuarios depositar tokens ERC20 en una bóveda y recibir acciones que representan su participación en los activos de la bóveda, y el contrato `Owned`, que es un contrato que gestiona la propiedad del contrato que lo hereda, en este caso el propietario del contrato es la dirección que haya sido pasada por parámetro al constructor (`_owner`) y por último tenemos una dirección que será la cual reciba los `fees` o tarifas que se cobren por pedir el flash loan.

A continuación me voy a centrar en una de las funciones en concreto del contrato en estudio, la función `flashLoan()`, que se vería de la siguiente forma:

![flashLoan function](https://github.com/user-attachments/assets/2d8f7201-9788-4148-9b16-94b110caa3e3)

Antes de ejecutar la flash loan se van a realizar ciertas comprobaciones como que la cantidad que se quiere prestar sea mayor que cero (`if (amount == 0)`), que el token pasado por parámetro sea el mismo que el usado en el contrato y por último que no haya un desbalance en la cantidad de tokens entre el `ERC20` y el `ERC4626`, esta comprobación será importante más adelante. El resto de la función es la transferencia de tokens al recipiente, suponemos que esta parte del código es correcta.

## Contrato `UnstoppableMonitor.sol`

En el constuctor del contrato se inicializará el _vault_ asociado al monitor, este contrato simboliza ese contrato de monitorización que se meciona en el enunciado, se vería de la siguiente forma:

![monitor constructor](https://github.com/user-attachments/assets/dbb86a97-ea4a-41dc-ab0a-60f83450a21f)

Después tenemos la función `onFlashLoan()` que será la función de callback cuando se llame a `flashLoan()` en este contrato, también suponemos que no hay errores en esta función.

![onFlashLoan function](https://github.com/user-attachments/assets/807ef230-bfc3-4bfa-b4a3-18cbd117457f)

Y por último tenemos la función `checkFlashLoan()` la cual va a realizar una llamada al contrato `UnstoppableVault.sol` para pedir un préstamo de tokens, si la función es satisfactoria, lanzará un evento indicando que no ha habido ningún problema al ejecutar el flash loan, pero si la función falla por alguna razón **el contrato pausará el _vault_** y transferirá el _ownership_ a una dirección para que se pueda revuisar que ha pasado. Exactamente este es nuestro objetivo, queremos mediante transferencias de tokens conseguir que al llamar a la función `flashLoan()` se produzca algún error y el contrato monitor pause el _vault_. La función se vería de la siguiente manera:

![checkFlashLoan function](https://github.com/user-attachments/assets/788c5747-13e2-48cc-a9b8-faaecee6d20a)

>[!important]
>**Resumen**
>
>Recapitulando tenemos una función que ofrece préstamos usando el estándar ERC4626 junto al ERC20 con la funcionalidad de pausar el contrato si fuera necesario en caso de algún error inesperado, por otro lado tenemos un contrato monitor que prueba que la llamada al _flash loan_ no falle y si lo hace pausa el contrato. Entonces vamos a analizar alguna forma para poder influir en el préstamo de tokens de alguna forma y así conseguir que el contrato se detenga y no pueda ofrecer más préstamos

# Vulnerabilidad/es

Como nuestro objetivo es conseguir que el flash loan falle, tenemos que buscar la manera de _triggear_ o activar una de las excepciones en las comprobaciones iniciales, vamos por tanto a centrarnos en esos _checks_ iniciales que son los siguientes:

![flash loan checks](https://github.com/user-attachments/assets/2f258be2-49eb-4f49-a98b-dd69885aaf24)

- La primera restricción no es posible hacer que falle porque para llamar a la función `checkFlashLoan()` la cantidad de tokens debe ser positiva (`require(amount > 0);`).

- La segunda restricción tampoco podemos manipularla porque la función `checkFlashLoan()` solo puede ser llamada por el _owner_ del contrato por lo tanto nosotros como agentes externos no podemos pausar el contrato sin llamar a esta función.

- Por último, podemos notar que se llama a otra función del contrato que devuelve un balance y seguidamente se realiza una comparación de balances, vamos a investigar en profundidad de donde salen estos balances.

La variable `balanceBefore` se obtiene al llamar a la función `totalAssets()`

![totalAsset](https://github.com/user-attachments/assets/b0398fb9-6ca1-4218-a889-822f2a366e30)

Que pide el balance de la dirección del contrato de la _vault_ al contrato del ERC4626.

Por otro lado, en la sentencia `if` se hace una comparación entre la variable `balanceBefore` antes mencionada y el resultado de la función `convertToShares(totalSupply)`, donde el parámetro `totalSupply` hace referencia a la cantidad de tokens que hay en el contrato ERC20. En otras palabras, esta comprobación se realiza para sincronizar el balance de los tokens de ERC4626 y ERC20, **si hubiera un desbalance la función fallaría**.

![totalSupply ERC20](https://github.com/user-attachments/assets/99f2fbec-4371-4a6b-a222-0509541e2d62)

Por lo tanto, si transferimos tokens a alguno de los contratos que manejan dichos tokens conseguimos que se produzca un desbalance y la función falle sin tener que obtener permisos del contrato monitor o _vault_. Un ataque sútil pero elegante donde con una simple transferencia podemos bloquear el contrato por completo.

# Exploit/Ataque

Como tal no habría un exploit o un contrato atacante que va a ejecutar un exploit, para poder resolver este reto únicamente debemos transferir una cantidad de tokens de la que tenemos en posesión (recordemos que empezamos el reto con 10 DVT tokens) al contrato del token DVT y ya habríamos vulnerado el contrato ya que la próxima vez que el dueño del contrato monitor ejecutase la función `checkFlashLoan()` el contrato _vault_ se pausaría y nosotros como atacantes habremos conseguido nuestro objetivo.

# Test de Foundry

Por lo tanto el test de foundry para probar nuestra vulnerabildiad quedaría de la siguiente forma:

![foundry test](https://github.com/user-attachments/assets/2e9b8d06-1554-4550-ae19-818bdfd0b67f)

Si ejecutamos el siguiente comando dentro del proyecto podremos comprobar que la vulnerabilidad podría ser explotada:

```bash
forge test --mp test/unstoppable/Unstoppable.t.sol
```

La salida sería la siguiente:

![terminal output](https://github.com/user-attachments/assets/df6e718e-ea3d-4cba-a2ce-5bffb1bfe0e8)

Esto sería todo para este write-up, no he explorado otras vías aunque he revisado bien los contratos y no he encontrado nada más concluyente. En este caso podemos ver como una incorrecta sincronización de balances puede suponer el bloqueo de nuestro servicio afectando a la confianza del mismo, no se producen daños directos pero hemos podido afectar negativamente al contrato siendo un usuario no privilegiado.
