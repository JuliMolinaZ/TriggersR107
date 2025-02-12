DELIMITER $$

DROP TRIGGER IF EXISTS trg_update_recolectado_picklist $$

CREATE TRIGGER trg_update_recolectado_picklist
BEFORE UPDATE ON PickListDetalle
FOR EACH ROW
BEGIN
    DECLARE nueva_cantidad_restante INT;
    DECLARE nuevo_status_producto VARCHAR(10);
    DECLARE current_stock INT;

    -- Verificamos si Recolectado es impar (1, 3, 5, 7, etc.)
    IF NEW.Recolectado % 2 = 1 THEN
        -- Primera vez (cuando Recolectado pasa a 1)
        IF OLD.CantidadSurtida IS NULL OR OLD.CantidadSurtida = 0 THEN
            SET NEW.CantidadSurtida = NEW.CantidadSurtida;
            SET NEW.SurtidoAcumulado = NEW.CantidadSurtida;
        ELSE
            -- Despues de primera actualizacion: acumulamos CantidadSurtida con CantidadRestante
            SET NEW.CantidadSurtida = OLD.CantidadSurtida + NEW.CantidadRestante; 
            SET NEW.SurtidoAcumulado = NEW.CantidadRestante;
        END IF;

        -- Calcular la cantidad restante 
        SET nueva_cantidad_restante = GREATEST(OLD.CantidadRequerida - NEW.CantidadSurtida, 0);

        -- Determinar el nuevo status del producto
        IF nueva_cantidad_restante = 0 AND NEW.CantidadSurtida >= OLD.CantidadRequerida THEN
            SET nuevo_status_producto = 'Total';
        ELSE
            SET nuevo_status_producto = 'Parcial';
        END IF;

        -- Asignamos los valores calculados
        SET NEW.CantidadRestante = nueva_cantidad_restante;
        SET NEW.StatusProducto = nuevo_status_producto;

        -- Actualizar StatusPickList en PickList si el StatusProducto es 'Parcial' o 'Total'
        IF nuevo_status_producto IN ('Parcial', 'Total') THEN
            UPDATE PickList
            SET StatusPickList = 'Recolectado'
            WHERE PickListID = NEW.PickListID;
        END IF;

        -- Seleccionar el Stock desde ProductosUbicacion utilizando ProductoUbicacionID
        SELECT Stock INTO current_stock
        FROM ProductosUbicacion
        WHERE ProductoID = NEW.ProductoID AND ProductoUbicacionID = NEW.UbicacionID;

        -- Actualización del Stock
        UPDATE ProductosUbicacion
        SET Stock = Stock - NEW.SurtidoAcumulado
        WHERE ProductoID = NEW.ProductoID AND ProductoUbicacionID = NEW.UbicacionID;

        -- Insertar en la tabla de logs
        INSERT INTO LogsSurtido (
            NewRecolectado, NewStock, NewSurtidoAcumulado, 
            OldRecolectado, OldStock, OldSurtidoAcumulado, 
            OperationDate, PickListDetalleID, ProductoID
        ) 
        VALUES (
            NEW.Recolectado, 
            (SELECT Stock FROM ProductosUbicacion WHERE ProductoID = NEW.ProductoID AND ProductoUbicacionID = NEW.UbicacionID), 
            NEW.SurtidoAcumulado, 
            OLD.Recolectado, 
            current_stock, 
            OLD.SurtidoAcumulado, 
            DATE_SUB(NOW(), INTERVAL -6 HOUR),
            NEW.PickListDetalleID, 
            NEW.ProductoID
        );

        -- Pasar Recolectado al siguiente número par
        SET NEW.Recolectado = NEW.Recolectado + 1;

    ELSE
        -- Si Recolectado es par, no se permite ninguna actualización
        -- Mantener los valores anteriores, sin hacer cambios
        SET NEW.CantidadSurtida = OLD.CantidadSurtida;
        SET NEW.SurtidoAcumulado = OLD.SurtidoAcumulado;
        SET NEW.CantidadRestante = OLD.CantidadRestante; 
    END IF;

END $$

DELIMITER ;






-- PRUEBAS
 
-- Prueba 1
UPDATE PickListDetalle 
SET CantidadSurtida = 10, Recolectado = 1 
WHERE PickListID = 'PL100' AND UbicacionID = 'PU100';

SELECT * FROM `PickListDetalle` WHERE PickListID = 'PL100' AND UbicacionID = 'PU100';

SELECT * FROM `ProductosUbicacion` WHERE ProductoID = 'PRD100' AND ProductoUbicacionID = 'PU100';



-- Prueba 2
UPDATE PickListDetalle 
SET CantidadSurtida = 2, Recolectado = 3 
WHERE PickListID = 'PL100' AND UbicacionID = 'UB100';

SELECT * FROM `PickListDetalle` WHERE PickListID = 'PL100' AND UbicacionID = 'UB100';

SELECT * FROM `ProductosUbicacion` WHERE ProductoID = 'PRD100' AND UbicacionID = 'UB100';

-- Prueba 3

UPDATE PickListDetalle 
SET CantidadSurtida = 13, Recolectado = 5 
WHERE PickListID = 'PL100' AND UbicacionID = 'UB100';

SELECT * FROM `PickListDetalle` WHERE PickListID = 'PL100' AND UbicacionID = 'UB100';

SELECT * FROM `ProductosUbicacion` WHERE ProductoID = 'PRD100' AND UbicacionID = 'UB100';



-- ACTUALIZACIONES VALORES 0


UPDATE PickListDetalle SET CantidadSurtida = 0, Recolectado = 0, StatusProducto = 'Pendiente', CantidadRestante = 25 WHERE PickListID = 'PL100' AND UbicacionID = 'PU100';

UPDATE PickListDetalle SET CantidadSurtida = 0, Recolectado = 0, StatusProducto = 'Pendiente', CantidadRestante = 30 WHERE PickListID = 'PL100' AND UbicacionID = 'PU200';


SELECT * FROM `PickListDetalle` WHERE PickListID = 'PL100' AND UbicacionID = 'PU100';

SELECT * FROM `PickList` WHERE PickListID = 'PL100';

SELECT * FROM `ProductosUbicacion` WHERE ProductoID = 'PRD100' AND ProductoUbicacionID = 'PU100';





SELECT * FROM `PickListDetalle` WHERE PickListID = 'PL100' AND UbicacionID = 'PU100';

SELECT * FROM `PickList` WHERE PickListID = 'PL100';

SELECT * FROM `ProductosUbicacion` WHERE ProductoID = 'PRD200' AND ProductoUbicacionID = 'PU100';


