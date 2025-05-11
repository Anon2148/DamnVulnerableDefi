# Introducción

Este reporte se ha realizado sobre uno de los retos que podemos encontrar en la plataforma online [Damn Vulnerable DeFi](https://www.damnvulnerabledefi.xyz/) llamado [Unstoppable](https://www.damnvulnerabledefi.xyz/challenges/naive-receiver/). Las instruciones del reto se pueden consultar en la siguiente imagen:

![naive receiver instructions](https://github.com/user-attachments/assets/4f96c6d8-9714-41ee-93a5-80e0a1da29b8)

> [!NOTE]
> **Traducción:**
> Hay un fondo con 1000 WETH de saldo que ofrece préstamos flash. Tiene una comisión fija de 1 WETH. La _pool_ soporta meta-transacciones mediante la integración con un contrato forwarder sin permisos.
>
> Un usuario ha desplegado un contrato de muestra con 10 WETH de saldo. Parece que puede ejecutar préstamos flash de WETH.
>
> ¡Todos los fondos están en riesgo! Rescata todos los WETH del usuario y del pool, y deposítalos en la cuenta de recuperación designada.

Nuestro objetivo por tanto es investigar los contratos para obtener tanto los fondos del usuario que desplegó el contrato de prueba así como los fondos de la _pool_, un punto interesante es el hecho de que la pool soporta meta-transacciones, las cuales son transacciones en la blockchain donde el contrato o cuenta que originó la transacción no paga los gastos de gas de dicha transacción sino que lo hace un contrato intermedio que comprueba la firma de la transacción con el firmante. Esto puede ser interesante si el contrato de la _pool_ depende del contrato que produce las meta-transacciones, lo veremos según avancemos en nuestro análisis. Más información en el siguiente [enlace](https://ethereum.stackexchange.com/questions/63180/meta-transaction-explanation).

# Análisis de nuestro reto

Bien definidos los conceptos del reto podemos pasar a realizar el análisis de los contratos presentes.

## Contrato `NaiveReceiverPool.sol`

El constructor junto a las variables del contrato son las siguientes:

![constructor](https://github.com/user-attachments/assets/134e2184-02fb-4ce7-bd49-b0e04ea7a97e)

- `weth`: Contrato del token WETH de wrapper sobre ETH usando ERC20
- `trustedForwarder`: Dirección que designa al contrato de meta-transacciones (más abajo)
- `feeReceiver`: Dirección que va a recibir los _fees_ de los flash loans

Más abajo tenemos la función `withdraw`:

![withdraw function](https://github.com/user-attachments/assets/c6226bc5-9133-4fa5-a376-d6dd181c037c)

Esta función reduce el balance de la dirección que devuelve la función `_msgSender()` (ver más abajo), y transfiere la cantidad pasada por parámetro a la dirección pasada por parámetro.

Pasamos a la función de `_msgSender()`

![_msgSender function](https://github.com/user-attachments/assets/5952bbe0-ce38-4156-8d51-0fcb4ffbfd9d)

Esta función tiene bastante relevancia ya que si nos fijamos el resultado que retorna la función va a cambiar dependiendo de quien sea el `msg.sender` y la longitud de los datos de la transacción sea mayor de 20 bytes. Esto puede ser un punto de fallo crítico a la hora de vulnerar el contrato ya que podemos devolver la dirección que esté en los últimos 20 bytes del `msg.data`.

## Contrato `FlashLoanReceiver.sol`

La única función relevante de este contrato es `onFlashLoan()`:

![onFlashLoan() function](https://github.com/user-attachments/assets/b1b76a99-15ba-4077-a01c-208f24332119)

Esta función devolverá los tokens prestados en la flash loan y pagará el fee correspondiente de 1 WETH para que la flash loan no revierta.

## Contrato `BasicForwarder.sol`

El contrato BasicForwarder va a realizar la funcionalidad de las meta-transacciones implementando el EIP-712 del autor solady (_Contract for EIP-712 typed structured data hashing and signing._), vamos a destacar dos funciones:

![checkRequest function](https://github.com/user-attachments/assets/73cf9ef3-20f0-49fd-943b-403aa5191859)

La función checkRequest realizará comprobaciones sobre los parámetros de la request que queremos ejecutar como son el nonce o el deadline para no ejecutar request repetidas, un punto a destacar es la comprobación de la firma que se pasa al ejecutar la request y el firmante de la request los cuales tienen que coincidir para evitar firmar acciones por parte de otra dirección.

Por otro lado tenemos la función `execute()`:

![execute function](https://github.com/user-attachments/assets/f3ebc151-7d2e-4a2f-8388-ab839d60bd3a)

Esta función ejecutará primero la función `checkRequest()` mencionada anteriormente, para después inicializar las variables que se usarán en el `call` para ejecutar la request. Como vemos al crear el payload se concatena la dirección que hayamos puesto en el campo `from` que debe coincidir con el firmante de la request.

## Contrato `Multicall.sol`

Este contrato es abstracto y solo contiene una única función la cual se encarga de agrupar multiples llamadas en una sola transacción, además estas llamadas se realizan con la función `delegateCall`, la cual ejecuta código de un contrato en el contexto del contrato que lo ha llamado (mismo msg.value y msg.data).

![multicall contract](https://github.com/user-attachments/assets/489af55b-83d6-4e18-a060-442093954c52)

# Análisis de vulnerabilidades

Con este análisis breve vamos a buscar posibles vulnerabilidades que puedan existir para conseguir nuestro objetivo que es drenar el contrato `BasicForwarder.sol` y `NaiveReceiverPool.sol`, vamos a empezar con el primero mencionado. Para ello nos tenemos que fijar en la función `onFlashLoan()` la cual se ejecutará cuando el usuario del contrato llame a la función `flashLoan()` de la _pool_.

![key part receiver flash loan](https://github.com/user-attachments/assets/6a9c218e-af9f-45d4-a141-b38cba6ffd71)

Esta parte de la función calcula la cantidad de _fee_ que debe pagar el usuario que utilice la flash loan, en este caso 1 WETH, junto a la cantidad de WETH pedida en el flash loan. A continuación, se ejecuta una función vacía que no afecta al valor del token y por último se aprueba el pago de la _fee_ a la pool. Como podemos comprobar este contrato no realiza ninguna acción adicional con los tokens prestados **ni comprueba si ha recibido 0 tokens WETH**, pero paga el _fee_ para que la transacción no revierta. Si conseguimos de alguna forma llamar suficientes veces al contrato de la _pool_ y designamos al recibidor de los tokens como la dirección del contrato `FlashLoanReceiver.sol` con una cantidad de 0 tokens WETH vamos a conseguir drenar los tokens del contrato que serán destinados a la dirección del _fee receiver_ la cual comentamos en el constructor de la _pool_.

Una forma de hacer esto sería con la función `multicall`, esta función es perfecta para este propósito ya que podemos ejecutar una determinada función un número de veces determinado, como en el contrato `FlashLoanReceiver.sol` hay depositados 10 WETH, podemos crear un array de 10 posiciones donde cada posición tenga una llamada a `flashLoan()` donde el recibidor sea el contrato que queremos drenar, esto se verá con más detalle en la parte del exploit.

Digamos que el ataque anterior fuese exitoso, ahora en la _pool_ habría 1010 tokens WETH los cuáles tenemos que obtener, vamos a ver posibles vías de explotación.

> [!CAUTION]
> Vía 1 BasicForwarder + función withdraw (la que yo tomé inicialmente):
>
> Después de un rato estudiando los contratos, se me ocurrión una forma de intentar drenar la _pool_. Como hemos visto en el análisis, tenemos un contrato que realiza meta-transacciones firmadas donde nos podemos ahorrar pagar el gas, además que tenemos una función `withdraw` en el contrato de la _pool_ que si es llamada por el contrato `BasicForwarder.sol` no devuelve la dirección del `msg.sender` sino la dirección que haya en los últimos 20 bytes del `msg.data`. Por lo que en teoría si yo manipulaba el `msg.data` para que la dirección de la que se iban a retirar los fondos fuera la de la _pool_ ya habría conseguido mi objetivo.
>
> ![_msgSender](https://github.com/user-attachments/assets/a0a978a5-e5d6-4970-b6ac-343c27e95f9d)
>
> Fui a probarlo pero me fallaba todas las veces, daba igual que cambiase que siempre fallaba el test, incluso estuve _debuggeando_ manualmente el contrato para ver que me estaba devolviendo la función de arriba y descubrí que mi idea inicial no era correcta, dicha función siempre me devolvía la dirección del creador de la _request_ que en este caso era mí dirección como atacante (player) la cual no tenía fondos, por lo que el test intentaba retirar fondos de una cuenta sin fondos y por eso revertía la transacción. Esto pasaba porque en la función `execute` del contrato que ofrecía las meta-transacciones siempre se concatenaba al final del payload de la llamada la dirección del firmante de la request invalidando mi ataque.

> [!TIP]
> Vía 2 BasicForwarder + Multicall + función withdraw
>
> Esta solución es algo más compleja pero es la forma correcta de drenar la _pool_.


