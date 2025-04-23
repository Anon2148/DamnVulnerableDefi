# Introducción

Este reporte se ha realizado sobre uno de los retos que podemos encontrar en la plataforma online [Damn Vulnerable DeFi](https://www.damnvulnerabledefi.xyz/) llamado [Truster](https://www.damnvulnerabledefi.xyz/challenges/truster/). Las instruciones del reto se pueden consultar en la siguiente imagen:

![truster instructions](https://github.com/user-attachments/assets/ac5aa119-11aa-44aa-88ed-7f942543a986)

> [!NOTE]
> **Traducción:**
> Cada vez son más los pools de préstamos que ofrecen _flashloans_. En este caso, se ha lanzado un nuevo fondo que ofrece préstamos flash de fichas DVT de forma gratuita.
>
> El _pool_ tiene 1 millón de fichas DVT. Tú no tienes nada.
>
> Para superar este reto, rescata todos los fondos del pool ejecutando una única transacción. Deposita los fondos en la cuenta de recuperación designada.

Poco más podemos añadir, se nos presenta una _pool_ de fichas DVT que ofrece préstamos gratuitos, existen 1 millón de fichas en el pool y debemos depositar esos fondos en una cuenta de _recovery_ en una sola transacción. Empecemos pues!!

# Apunte: Qué es una flash loan (O préstamo flash)

Para quién no este familiarizado con este concepto, un flash loan se puede definir como:

>[!NOTE]
>**Binance Academy**
>
> ¿Un préstamo concedido por extraños que no requiere que el usuario sacrifique parte de su propio dinero? Es posible, bajo una condición: los sujetos deben pagar al prestamista en el marco de la misma transacción que emitió los fondos. Suena extraño, ¿no es así? ¿Qué puedes hacer con un préstamo que debe ser devuelto segundos más tarde?
> 
> Pues bien, resulta que en esa misma transacción puedes realizar llamadas a smart contracts. Si puedes generar más dinero utilizando tu préstamo, podrás devolver el dinero y embolsarte el beneficio en un abrir y cerrar de ojos.

>[!NOTE]
>**Bit2me Academy**
>
>Un flash loan o préstamo flash no es más que un préstamo programado sobre un [**protocolo DeFi**](https://academy.bit2me.com/que-es-defi-o-finanzas-descentralizadas/), capaz de ofrecer una provisión de fondos a los usuarios sin que estos necesiten aportar una garantía (ni en criptomonedas, ni de ningún tipo) por los fondos que le son prestados. El protocolo DeFi brinda acceso al usuario de unos fondos para que éste pueda utilizarlos y devolverlos al protocolo en una misma operación, incluyendo las comisiones correspondientes.
>
>En blockchain esto es posible, porque existe la posibilidad de programar una transacción para que tome los fondos prestados, los movilice por distintos [**smart contracts**](https://academy.bit2me.com/que-son-los-smart-contracts/) de otros protocolos, se realicen las operaciones de intercambio pertinentes y, al final de esa misma transacción, el dinero del préstamo y sus comisiones sean reintegradas al protocolo inicial mientras el usuario se retira con sus ganancias.

>[!NOTE]
>**ChatGPT**
>
>Un _flash loan_ (o préstamo relámpago) es un tipo de préstamo que solo existe dentro de una única transacción en una blockchain como Ethereum. Permite a un usuario pedir prestados fondos sin necesidad de colateral, con la condición de que el préstamo sea devuelto en su totalidad dentro de la misma transacción. Si no se devuelve al final de la operación, la transacción completa se revierte automáticamente, como si nunca hubiera ocurrido.
>
>Este mecanismo es posible gracias a la forma en que funcionan los contratos inteligentes: todo el conjunto de operaciones debe completarse exitosamente, o ninguna tiene efecto. Los _flash loans_ se usan comúnmente para aprovechar oportunidades de arbitraje, refinanciar deudas, o mover fondos entre protocolos para optimizar rendimientos, pero también han sido explotados en ataques sofisticados si los protocolos no están bien diseñados.

De forma menos técnica se podría decir que un flash loan es un mecánismo donde un prestamista presta una cantidad de fondos (tokens habitualmente) a un prestatario a través de contratos inteligentes, con la particularidad de que el recibidor de los fondos puede hacer otras operaciones con esos fondos en la misma transacción y debe devolver dichos fondos después de usarlos junto a una comisión. Todo esto respaldado por un sistema descentralizado como es la blockchain.

# Análisis de nuestro reto

Bien definidos los conceptos del reto podemos pasar a realizar el análisis del único contrato.

## Contrato `TrusterLenderPool.sol`

Nos encontramos ante un contrato simple que usará otro contrato llamado `DamnValuableToken` como token para realizar las _flashloans_, este contrato importa la versión de _solmate_ modificada del estándar ERC20 definido como _Modern and gas efficient ERC20 + EIP-2612 implementation._ (Implementación moderna y gas eficiente de ERC20 + EIP-2612), esto será relevante más adelante. El contrato del token sería el siguiente:

![Damn Valuable Token](https://github.com/user-attachments/assets/7ec8600b-b17e-431b-ad85-de35e6733c77)

Este token será inicializado en el constructor de nuestro contrato `TrusterLenderPool.sol`, el cual será usado por la única función que existe, esta función implementará el sistema del _flashloan_, el contrato quedaría entonces de la siguiente manera:

![TrsuterLenderPool contract](https://github.com/user-attachments/assets/02ec37b3-652d-4c86-a5f4-c4349e689de6)

# Vulnerabilidad/es

Como en este contrato solo consta de una función con la que podemos interactuar, vamos a centrar nuestro análisis en esa función, si nos fijamos en la imagen de arriba y vamos analizando línea por línea la función obtenemos lo siguiente:

>[!important]
>**Función `flashLoan()`**
>
>- `uint256 balanceBefore = token.balanceOf(address(this));`: Esta línea devolverá el balance de tokens de la dirección de la pool actual.
>- `token.transfer(borrower, amount);`: Esta línea modificará el contrato token asignando la cantidad de tokens `amount` a la dirección asignada en `borrower`.
>- `target.functionCall(data);`: Esta línea ejecutará una llamada `call` a la función pasada en la variable `data`.
>- `if (token.balanceOf(address(this)) < balanceBefore) {...}`: Esta sentencia if comprobará si el balance en el instante actual es el mismo que el que teniamos al inicio de la ejecución de la función.

Con esto podemos concluir que se nos transfieren una cantidad de tokens determinada, podemos ejecutar una función con `call` y por último debemos devolver los tokens prestados. Sin embargo hay varios problemas de seguridad en esta función.

>[!warning]
>1. No comprobamos que la cantidad que se transfiere sea mayor que la cantidad de tokens de la pool, aunque si intentamos transferir más tokens de los existentes la función transfer revertirá por _underflow_ (versión de solidity >= 0.8.x)
>2. No se comprueba que contiene la variable `data`, esto es una vulnerabilidad muy grave ya que se puede ejecutar funciones privilegiadas en nombre de la pool.
>3. No comprobamos el `target` que se pasa por parámetro, si pasamos una dirección que pueda interactuar con el contrato de tokens sin restricciones podremos ejecutar funciones privilegiadas.

El contrato permite una llamada arbitraria en su propio nombre, **sin restricciones**, lo que puede usarse para alterar permisos (`approve`) de otras cuentas (como la de un atacante) sin cambiar el balance de los tokens y por eso el chequeo `balanceBefore` pasa, aunque el control del dinero ya se haya perdido. Vamos a pasar a la creación de nuestro contrato atacante donde se verá más claro la explotación de la vulnerabilidad.

# Exploit

El exploit se encuentra en el archivo `TrusterLenderPoolAttacker.sol`, vamos a explicar la función principal que ejecutará el ataque. La función sería la siguiente:

![attack function](https://github.com/user-attachments/assets/92b864ac-391a-47d6-9a03-58fe5b74825c)

Como podemos ver llamamos a la función `flashLoan()` con un amount de 0 para que pase el check final, como `borrower` el contrato atacante, como `target` el contrato `token` y como `data` le pasamos la función `approve` con la dirección del contrato que va a trasnferir los tokens, este caso el contrato atacante, y el balance total de la _pool_ que es el contrato del que queremos conseguir los tokens.

**De forma más resumida, como podemos ejecutar cualquier función que queramos a través del contrato de la _pool_, vamos a ejecutar la función `approve` para dar permiso al contrato atacante a transferir una cantidad de tokens, para luego transferir los tokens de la _pool_ hacia la cuenta recovery y así vaciar la pool.**

Por lo tanto el test de foundry para probar nuestro exploit quedaría de la siguiente forma:

![foundry test](https://github.com/user-attachments/assets/e343efd4-b3c7-46f8-914b-64f22a913a85)

Solo debemos inicializar(desplegar en un caso real) el contrato y llamar a la función del contrato que se encargará de todo, después de la ejecución todos los tokens pasarán a la dirección `recovery` asignada en el constructor.

Si ejecutamos el siguiente comando dentro del proyecto podremos comprobar que nuestro exploit funciona correctamente:

```bash
forge test --mp test/truster/Truster.t.sol
```

![terminal test pass](https://github.com/user-attachments/assets/fd750f38-5d73-4a12-8d07-98daebe7198b)

Hemos conseguido vulnerar este contrato consiguiendo vaciar la pool y transferir los fondos a la cuenta recovery, así demostramos que es bastante importante aplicar buenas prácticas en nuestro código como la validación en la entrada del usuario así como la dirección que puede aprobar la transferencia de tokens hacia direcciones confiables. También debemos tener en cuenta las dependencias de las que hace uso nuestro contrato porque pueden suponer riesgos de seguridad abriendo la posibilidad de ataques.

Happy Hacking ;)
